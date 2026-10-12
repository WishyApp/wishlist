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
-- - SELECT policies are not touched.

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
    -- Legacy layout: "<wish id>/..." of a wish in a wishlist of the user
    OR EXISTS (
      SELECT 1
      FROM public.wishs w
      JOIN public.wishlists wl ON wl.id = w.wishlist_id
      WHERE wl.id_owner = (SELECT auth.uid())
        AND (storage.foldername(p_name))[1] = w.id::text
    );
$$;

REVOKE ALL ON FUNCTION public.can_write_wish_image(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_write_wish_image(text) TO authenticated;


-- 3. storage.objects policies for wish-images

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


-- 4. Permissive policies add up (OR): fail if any other INSERT, UPDATE,
-- DELETE or ALL policy still targets the wish-images bucket (or has no bucket
-- condition), for instance one created by hand on a project.

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
    AND (
      coalesce(qual, '') || ' ' || coalesce(with_check, '') LIKE '%wish-images%'
      OR (coalesce(qual, '') NOT LIKE '%bucket_id%'
          AND coalesce(with_check, '') NOT LIKE '%bucket_id%')
    )
    AND policyname NOT IN (
      'Users can upload their own wish images',
      'Users can update their own wish images',
      'Users can delete their own wish images'
    );

  IF extra IS NOT NULL THEN
    RAISE EXCEPTION 'Unexpected wish-images write policies left: %', extra;
  END IF;
END $$;


-- Verification: tests in supabase-tests/wish_images_policies.sql.
-- Buckets: SELECT id, public, file_size_limit, allowed_mime_types FROM storage.buckets;
