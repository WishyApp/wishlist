-- Restrict writes on the wish-images bucket to the owner of the image, and
-- declare that bucket in the repo.
--
-- - New wish images live under "<auth.uid()>/<wish id>/<file>", like avatars
--   live under "<auth.uid()>/<file>". Only that user inserts, updates or
--   deletes objects under their own prefix.
-- - Images uploaded before this change live under "<wish id>/<file>" (the
--   wishs.icon_url column stores that path, not a URL). The owner of the wish
--   keeps full control over the folder of their own wishes, so replacing or
--   deleting a legacy image still works. A wish id is never a user id, so the
--   two layouts cannot overlap.
-- - The wish-images bucket stays public (the app reads public URLs) and
--   accepts WebP images only, which is what the app uploads. The limits apply
--   to new uploads only, existing objects are left as they are. The avatars
--   bucket is not touched.
-- - SELECT is restricted by the same rule: the old policy let any signed-in
--   user list every object name of the bucket, including images of wishes in
--   private wishlists, and the bucket is public so each name is a fetchable
--   URL. Names now have to be guessed. The bucket is public, so image URLs
--   keep working without a SELECT policy (the app only uses public URLs). The storage API still needs SELECT
--   on the caller's own objects to remove or upsert them.
-- - Legacy images of a wish that has since been deleted match no rule any more
--   (the wish is gone), so only service_role can remove them. The app removes
--   the files before deleting a wish (wish form and multi-select), but
--   deleting a wishlist (delete_or_archive_wishlist) does not touch storage:
--   that is the remaining source of orphans, also for the new layout.
--   Cleaning them up is a follow-up.

-- 1. Bucket configuration, idempotent.

INSERT INTO storage.buckets (id, name)
VALUES ('wish-images', 'wish-images')
ON CONFLICT (id) DO NOTHING;

-- public, file_size_limit and allowed_mime_types are columns added by the
-- storage service itself: they exist on a Supabase project, but not on a bare
-- schema, where there is nothing to configure.
DO $$
BEGIN
  IF (
    SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'storage'
      AND table_name = 'buckets'
      AND column_name IN ('public', 'file_size_limit', 'allowed_mime_types')
  ) = 3 THEN
    UPDATE storage.buckets
    SET public = true,
        file_size_limit = 5242880,
        allowed_mime_types = ARRAY['image/webp']
    WHERE id = 'wish-images';
  END IF;
END $$;


-- 2. Shared rule. SECURITY INVOKER: it reads wishs and wishlists with the
-- caller's rights, so it only sees the wishes the caller can already read.

CREATE OR REPLACE FUNCTION public.can_write_wish_image(p_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT
    -- New layout: "<user id>/..."
    (storage.foldername(p_name))[1] = (SELECT auth.uid())::text
    -- Legacy layout: "<wish id>/..." of a wish in a wishlist of the user.
    -- Primary-key lookup on wishs; the CASE keeps the bigint cast from running
    -- on a folder that is not a number.
    OR EXISTS (
      SELECT 1
      FROM public.wishs w
      WHERE w.id = CASE
            WHEN (storage.foldername(p_name))[1] ~ '^[0-9]{1,18}$'
            THEN (storage.foldername(p_name))[1]::bigint
          END
        AND public.is_wishlist_owner(w.wishlist_id)
    );
$$;

REVOKE ALL ON FUNCTION public.can_write_wish_image(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_write_wish_image(text) TO authenticated;


-- 3. storage.objects policies for wish-images

DROP POLICY IF EXISTS "Authenticated users can alter all wish images gs2bfi_0" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own wish images" ON storage.objects;
CREATE POLICY "Users can read their own wish images"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'wish-images'
    AND public.can_write_wish_image(name)
  );

-- The legacy branch of can_write_wish_image is kept on INSERT only for app
-- versions that still upload to "<wish id>/" right after creating a wish.
-- Replacing or deleting a legacy image needs UPDATE and DELETE only.
-- TODO: once the minimum supported app version is the first release that
-- uploads under "<user id>/" (the one shipping F010, the one after 0.2.4+9 in
-- wishlist/pubspec.yaml), add a new migration that makes INSERT check the user
-- prefix only. The legacy branch can go entirely when the legacy images have
-- been migrated or purged.
DROP POLICY IF EXISTS "Authenticated users can alter all wish images gs2bfi_1" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own wish images" ON storage.objects;
CREATE POLICY "Users can upload their own wish images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'wish-images'
    AND public.can_write_wish_image(name)
  );

DROP POLICY IF EXISTS "Authenticated users can alter all wish images gs2bfi_2" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own wish images" ON storage.objects;
CREATE POLICY "Users can update their own wish images"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'wish-images'
    AND public.can_write_wish_image(name)
  )
  WITH CHECK (
    bucket_id = 'wish-images'
    AND public.can_write_wish_image(name)
  );

DROP POLICY IF EXISTS "Authenticated users can alter all wish images gs2bfi_3" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own wish images" ON storage.objects;
CREATE POLICY "Users can delete their own wish images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'wish-images'
    AND public.can_write_wish_image(name)
  );


-- 4. Permissive policies add up (OR): fail if any INSERT, UPDATE, DELETE or ALL
-- permissive policy on storage.objects is not in the list below, whatever its
-- condition says, for instance one created by hand on a project. Adding a
-- bucket with its own write policies means adding their names here (or in the
-- migration that introduces them).

DO $$
DECLARE
  extra text;
BEGIN
  SELECT string_agg(format('"%s" (%s)', policyname, cmd), ', ')
  INTO extra
  FROM pg_policies
  WHERE schemaname = 'storage'
    AND tablename = 'objects'
    AND permissive = 'PERMISSIVE'
    AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
    AND policyname NOT IN (
      -- wish-images, this migration
      'Users can upload their own wish images',
      'Users can update their own wish images',
      'Users can delete their own wish images',
      -- avatars, 20251111150215_remote_schema
      'Auth users can upload their own avatar',
      'Auth users can update their own avatar',
      'Auth users can delete their own avatar'
    );

  IF extra IS NOT NULL THEN
    RAISE EXCEPTION 'Unexpected write policies on storage.objects: %', extra;
  END IF;
END $$;


-- Verification: tests in supabase-tests/wish_images_policies.sql.
-- Buckets: SELECT id, public, file_size_limit, allowed_mime_types FROM storage.buckets;
