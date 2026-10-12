-- Write policies of the wish-images bucket
-- (20261012120000_restrict_wish_images_to_owner).
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

CREATE FUNCTION pg_temp.expect_denied(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: allowed, expected a denial', label;
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'ok   % (denied)', label;
END $$;

CREATE FUNCTION pg_temp.expect_rows(label text, statement text, expected int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  n int;
BEGIN
  EXECUTE statement;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> expected THEN
    RAISE EXCEPTION 'FAIL %: % row(s), expected %', label, n, expected;
  END IF;
  RAISE NOTICE 'ok   % (% row(s))', label, n;
END $$;

-- Bucket configuration (columns managed by the storage service, absent from
-- a bare storage schema)
DO $$
BEGIN
  IF (
    SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'storage' AND table_name = 'buckets'
      AND column_name IN ('public', 'file_size_limit', 'allowed_mime_types')
  ) = 3 THEN
    IF NOT EXISTS (
      SELECT 1 FROM storage.buckets b
      WHERE b.id = 'wish-images'
        AND to_jsonb(b) @> '{"public": true, "file_size_limit": 5242880, "allowed_mime_types": ["image/webp"]}'
    ) THEN
      RAISE EXCEPTION 'FAIL wish-images bucket not configured as expected';
    END IF;
  ELSE
    RAISE NOTICE 'skip bucket configuration check (bare storage schema)';
  END IF;
END $$;

-- Fixtures: A (acting user) and B. Wish 910001 is A's, 910003 is B's.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-a000-00000000000a'),
  ('00000000-0000-4000-a000-00000000000b');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-a000-00000000000a', 'test_a'),
  ('00000000-0000-4000-a000-00000000000b', 'test_b');
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility, is_closed) VALUES
  (900001, 'A public', '00000000-0000-4000-a000-00000000000a', '#FFFFFF', '00000000-0000-4000-a000-00000000000a', 'public', false),
  (900003, 'B public', '00000000-0000-4000-a000-00000000000b', '#FFFFFF', '00000000-0000-4000-a000-00000000000b', 'public', false);
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, quantity) VALUES
  (910001, 'A wish', '', 900001, '00000000-0000-4000-a000-00000000000a', 1),
  (910003, 'B wish', '', 900003, '00000000-0000-4000-a000-00000000000b', 1);
INSERT INTO storage.objects (bucket_id, name) VALUES
  ('wish-images', '00000000-0000-4000-a000-00000000000a/910001/old.webp'),
  ('wish-images', '00000000-0000-4000-a000-00000000000b/910003/old.webp'),
  ('wish-images', '910001/legacy.webp'),
  ('wish-images', '910001/legacy_thumb.webp'),
  ('wish-images', '910003/legacy.webp'),
  ('wish-images', '910003/legacy_thumb.webp'),
  ('wish-images', 'orphan.webp');
-- The avatars bucket is not declared by the migration: fixture for the check below.
INSERT INTO storage.buckets (id, name) VALUES ('avatars', 'avatars') ON CONFLICT (id) DO NOTHING;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000a', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000a", "role": "authenticated"}', true);

-- Insert
SELECT pg_temp.expect_rows('image uploaded under own prefix',
  $q$INSERT INTO storage.objects (bucket_id, name) VALUES ('wish-images', '00000000-0000-4000-a000-00000000000a/910001/new.webp')$q$, 1);
SELECT pg_temp.expect_denied('image uploaded under the prefix of another user',
  $q$INSERT INTO storage.objects (bucket_id, name) VALUES ('wish-images', '00000000-0000-4000-a000-00000000000b/910003/new.webp')$q$);
SELECT pg_temp.expect_denied('image uploaded without prefix',
  $q$INSERT INTO storage.objects (bucket_id, name) VALUES ('wish-images', 'new.webp')$q$);
SELECT pg_temp.expect_denied('image uploaded in the folder of a wish of another user',
  $q$INSERT INTO storage.objects (bucket_id, name) VALUES ('wish-images', '910003/new.webp')$q$);
SELECT pg_temp.expect_denied('image uploaded with a leading slash before the own prefix',
  $q$INSERT INTO storage.objects (bucket_id, name) VALUES ('wish-images', '/00000000-0000-4000-a000-00000000000a/x.webp')$q$);
SELECT pg_temp.expect_rows('image uploaded in the folder of an own wish',
  $q$INSERT INTO storage.objects (bucket_id, name) VALUES ('wish-images', '910001/new.webp')$q$, 1);

-- Update (visible rows only: a row the policy hides is not updated)
SELECT pg_temp.expect_rows('own image updated',
  $q$UPDATE storage.objects SET name = name WHERE bucket_id = 'wish-images' AND name = '00000000-0000-4000-a000-00000000000a/910001/old.webp'$q$, 1);
SELECT pg_temp.expect_rows('legacy image of an own wish updated',
  $q$UPDATE storage.objects SET name = name WHERE bucket_id = 'wish-images' AND name = '910001/legacy.webp'$q$, 1);
SELECT pg_temp.expect_rows('image of another user updated',
  $q$UPDATE storage.objects SET name = name WHERE bucket_id = 'wish-images' AND name = '00000000-0000-4000-a000-00000000000b/910003/old.webp'$q$, 0);
SELECT pg_temp.expect_rows('legacy image of a wish of another user updated',
  $q$UPDATE storage.objects SET name = name WHERE bucket_id = 'wish-images' AND name = '910003/legacy.webp'$q$, 0);
SELECT pg_temp.expect_rows('image without prefix nor wish updated',
  $q$UPDATE storage.objects SET name = name WHERE bucket_id = 'wish-images' AND name = 'orphan.webp'$q$, 0);
SELECT pg_temp.expect_denied('own image renamed under the prefix of another user',
  $q$UPDATE storage.objects SET name = '00000000-0000-4000-a000-00000000000b/910003/stolen.webp' WHERE bucket_id = 'wish-images' AND name = '00000000-0000-4000-a000-00000000000a/910001/old.webp'$q$);
SELECT pg_temp.expect_denied('own legacy image renamed into the folder of another wish',
  $q$UPDATE storage.objects SET name = '910003/stolen.webp' WHERE bucket_id = 'wish-images' AND name = '910001/legacy_thumb.webp'$q$);

-- A wish pointing to a path does not give access to that path
UPDATE public.wishs SET icon_url = '910003/legacy.webp' WHERE id = 910001;
SELECT pg_temp.expect_rows('image of another user deleted through own wish reference',
  $q$DELETE FROM storage.objects WHERE bucket_id = 'wish-images' AND name = '910003/legacy.webp'$q$, 0);

-- Delete
SELECT pg_temp.expect_rows('own image deleted',
  $q$DELETE FROM storage.objects WHERE bucket_id = 'wish-images' AND name = '00000000-0000-4000-a000-00000000000a/910001/old.webp'$q$, 1);
SELECT pg_temp.expect_rows('legacy image and thumbnail of an own wish deleted',
  $q$DELETE FROM storage.objects WHERE bucket_id = 'wish-images' AND name IN ('910001/legacy.webp', '910001/legacy_thumb.webp')$q$, 2);
SELECT pg_temp.expect_rows('image of another user deleted',
  $q$DELETE FROM storage.objects WHERE bucket_id = 'wish-images' AND name LIKE '00000000-0000-4000-a000-00000000000b/%'$q$, 0);
SELECT pg_temp.expect_rows('legacy image of a wish of another user deleted',
  $q$DELETE FROM storage.objects WHERE bucket_id = 'wish-images' AND name IN ('910003/legacy.webp', '910003/legacy_thumb.webp')$q$, 0);
SELECT pg_temp.expect_rows('image without prefix nor wish deleted',
  $q$DELETE FROM storage.objects WHERE bucket_id = 'wish-images' AND name = 'orphan.webp'$q$, 0);

-- Other buckets are out of scope
SELECT pg_temp.expect_denied('avatars bucket still limited to the owner',
  $q$INSERT INTO storage.objects (bucket_id, name) VALUES ('avatars', '00000000-0000-4000-a000-00000000000b/x.webp')$q$);

RESET ROLE;
SET LOCAL ROLE anon;
SELECT pg_temp.expect_denied('image uploaded while not signed in',
  $q$INSERT INTO storage.objects (bucket_id, name) VALUES ('wish-images', '00000000-0000-4000-a000-00000000000a/910001/anon.webp')$q$);

ROLLBACK;
