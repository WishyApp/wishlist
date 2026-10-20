-- Read rules of wishlists, wishs and profiles
-- (20261012100000_restrict_private_wishlist_reads).
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

-- Functions created by postgres have no EXECUTE for PUBLIC by default
-- (20261012110000_restrict_anon_privileges): the helpers below are called
-- after switching role. Rolled back with the rest.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

-- Expects the number of rows a SELECT returns, with the current role.
CREATE FUNCTION pg_temp.expect_count(label text, statement text, expected int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  n int;
BEGIN
  EXECUTE statement INTO n;
  IF n <> expected THEN
    RAISE EXCEPTION 'FAIL %: % row(s), expected %', label, n, expected;
  END IF;
  RAISE NOTICE 'ok   % (% row(s))', label, n;
END $$;

CREATE FUNCTION pg_temp.act_as(user_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', user_id::text, true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
END $$;

-- Fixtures:
--   A: acting user, friend of B, has a pending request with P and D.
--   B: has a public wishlist, a private one, an archived public one (kept
--      for a completed wish) and a wishlist whose wish A booked, then made
--      private.
--   F: no relation with A; booked a wish of B's public wishlist.
--   S: no relation with A; has a public wishlist.
--   N: no relation with A; has a private wishlist only.
--   Q: no relation with A; has a private wishlist only, holding a wish A booked.
--   K, R: a blocked and a rejected friendship row with A; no wishlist.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-c000-00000000000a'),
  ('00000000-0000-4000-c000-00000000000b'),
  ('00000000-0000-4000-c000-00000000000f'),
  ('00000000-0000-4000-c000-00000000000d'),
  ('00000000-0000-4000-c000-000000000050'),
  ('00000000-0000-4000-c000-00000000005e'),
  ('00000000-0000-4000-c000-00000000000e'),
  ('00000000-0000-4000-c000-0000000000b1'),
  ('00000000-0000-4000-c000-0000000000e2'),
  ('00000000-0000-4000-c000-0000000000c9');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-c000-00000000000a', 'read_a'),
  ('00000000-0000-4000-c000-00000000000b', 'read_b'),
  ('00000000-0000-4000-c000-00000000000f', 'read_f'),
  ('00000000-0000-4000-c000-00000000000d', 'read_d'),
  ('00000000-0000-4000-c000-000000000050', 'read_p'),
  ('00000000-0000-4000-c000-00000000005e', 'read_s'),
  ('00000000-0000-4000-c000-00000000000e', 'read_n'),
  ('00000000-0000-4000-c000-0000000000b1', 'read_blocked'),
  ('00000000-0000-4000-c000-0000000000e2', 'read_rejected'),
  ('00000000-0000-4000-c000-0000000000c9', 'read_q');
INSERT INTO public.friendships (id, requester_id, receiver_id, status) VALUES
  (930001, '00000000-0000-4000-c000-00000000000a', '00000000-0000-4000-c000-00000000000b', 'accepted'),
  (930002, '00000000-0000-4000-c000-00000000000f', '00000000-0000-4000-c000-00000000000b', 'accepted'),
  (930003, '00000000-0000-4000-c000-000000000050', '00000000-0000-4000-c000-00000000000a', 'pending'),
  (930004, '00000000-0000-4000-c000-00000000000a', '00000000-0000-4000-c000-00000000000d', 'pending'),
  (930005, '00000000-0000-4000-c000-0000000000b1', '00000000-0000-4000-c000-00000000000a', 'blocked'),
  (930006, '00000000-0000-4000-c000-00000000000a', '00000000-0000-4000-c000-0000000000e2', 'rejected');
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility, deleted_at) VALUES
  (940001, 'A private',         '00000000-0000-4000-c000-00000000000a', '#FFFFFF', '00000000-0000-4000-c000-00000000000a', 'private', NULL),
  (940002, 'B public',          '00000000-0000-4000-c000-00000000000b', '#FFFFFF', '00000000-0000-4000-c000-00000000000b', 'public',  NULL),
  (940003, 'B private',         '00000000-0000-4000-c000-00000000000b', '#FFFFFF', '00000000-0000-4000-c000-00000000000b', 'private', NULL),
  (940004, 'B public archived', '00000000-0000-4000-c000-00000000000b', '#FFFFFF', '00000000-0000-4000-c000-00000000000b', 'public',  now()),
  (940005, 'B booked, now private', '00000000-0000-4000-c000-00000000000b', '#FFFFFF', '00000000-0000-4000-c000-00000000000b', 'private', NULL),
  (940006, 'S public',          '00000000-0000-4000-c000-00000000005e', '#FFFFFF', '00000000-0000-4000-c000-00000000005e', 'public',  NULL),
  (940007, 'N private',         '00000000-0000-4000-c000-00000000000e', '#FFFFFF', '00000000-0000-4000-c000-00000000000e', 'private', NULL),
  (940008, 'Q private, A booked a wish', '00000000-0000-4000-c000-0000000000c9', '#FFFFFF', '00000000-0000-4000-c000-0000000000c9', 'private', NULL);
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by) VALUES
  (950001, 'A wish',           '', 940001, '00000000-0000-4000-c000-00000000000a'),
  (950002, 'B public wish',    '', 940002, '00000000-0000-4000-c000-00000000000b'),
  (950003, 'B private wish',   '', 940003, '00000000-0000-4000-c000-00000000000b'),
  (950004, 'B archived wish',  '', 940004, '00000000-0000-4000-c000-00000000000b'),
  (950005, 'B booked wish',    '', 940005, '00000000-0000-4000-c000-00000000000b'),
  (950006, 'B other wish in the booked wishlist', '', 940005, '00000000-0000-4000-c000-00000000000b'),
  (950007, 'S wish',           '', 940006, '00000000-0000-4000-c000-00000000005e'),
  (950008, 'N wish',           '', 940007, '00000000-0000-4000-c000-00000000000e'),
  (950009, 'Q wish booked by A', '', 940008, '00000000-0000-4000-c000-0000000000c9');
INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id) VALUES
  ('00000000-0000-4000-c000-00000000000b', 950004, 940004);
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (950005, '00000000-0000-4000-c000-00000000000a', 1),
  (950002, '00000000-0000-4000-c000-00000000000f', 1),
  (950009, '00000000-0000-4000-c000-00000000000a', 1);

-- As A
SELECT pg_temp.act_as('00000000-0000-4000-c000-00000000000a');

-- wishlists
SELECT pg_temp.expect_count('own private wishlist read',
  $q$SELECT count(*) FROM public.wishlists WHERE id = 940001$q$, 1);
SELECT pg_temp.expect_count('public wishlist of a friend read',
  $q$SELECT count(*) FROM public.wishlists WHERE id = 940002$q$, 1);
SELECT pg_temp.expect_count('private wishlist of another user not read',
  $q$SELECT count(*) FROM public.wishlists WHERE id = 940003$q$, 0);
SELECT pg_temp.expect_count('archived public wishlist of another user read',
  $q$SELECT count(*) FROM public.wishlists WHERE id = 940004$q$, 1);
SELECT pg_temp.expect_count('wishlist holding a booked wish read although private',
  $q$SELECT count(*) FROM public.wishlists WHERE id = 940005$q$, 1);
SELECT pg_temp.expect_count('public wishlist of a user without relation read',
  $q$SELECT count(*) FROM public.wishlists WHERE id = 940006$q$, 1);
SELECT pg_temp.expect_count('private wishlist of a user without relation not read',
  $q$SELECT count(*) FROM public.wishlists WHERE id = 940007$q$, 0);
SELECT pg_temp.expect_count('wishlists read in all',
  $q$SELECT count(*) FROM public.wishlists WHERE id BETWEEN 940001 AND 940007$q$, 5);

-- wishs
SELECT pg_temp.expect_count('own wish read',
  $q$SELECT count(*) FROM public.wishs WHERE id = 950001$q$, 1);
SELECT pg_temp.expect_count('wish of a public wishlist of a friend read',
  $q$SELECT count(*) FROM public.wishs WHERE id = 950002$q$, 1);
SELECT pg_temp.expect_count('wish of a private wishlist of another user not read',
  $q$SELECT count(*) FROM public.wishs WHERE id = 950003$q$, 0);
SELECT pg_temp.expect_count('wish of an archived public wishlist read',
  $q$SELECT count(*) FROM public.wishs WHERE id = 950004$q$, 1);
SELECT pg_temp.expect_count('completed wish with its archived wishlist and owner profile read',
  $q$SELECT count(*) FROM public.user_completed_wishs c
       JOIN public.wishs w ON w.id = c.wish_id
       JOIN public.wishlists wl ON wl.id = w.wishlist_id
       JOIN public.profiles p ON p.id = wl.id_owner
      WHERE c.user_id = '00000000-0000-4000-c000-00000000000b'$q$, 1);
SELECT pg_temp.expect_count('booked wish read although its wishlist is private',
  $q$SELECT count(*) FROM public.wishs WHERE id = 950005$q$, 1);
SELECT pg_temp.expect_count('other wish of that private wishlist not read',
  $q$SELECT count(*) FROM public.wishs WHERE id = 950006$q$, 0);
SELECT pg_temp.expect_count('wish of a public wishlist of a user without relation read',
  $q$SELECT count(*) FROM public.wishs WHERE id = 950007$q$, 1);
SELECT pg_temp.expect_count('wish of a private wishlist of a user without relation not read',
  $q$SELECT count(*) FROM public.wishs WHERE id = 950008$q$, 0);

-- The query of the booked wishes screen: booking, wish, wishlist, owner.
SELECT pg_temp.expect_count('booked wish with its wishlist and owner profile read',
  $q$SELECT count(*) FROM public.wish_taken_by_user t
       JOIN public.wishs w ON w.id = t.wish_id
       JOIN public.wishlists wl ON wl.id = w.wishlist_id
       JOIN public.profiles p ON p.id = wl.id_owner
      WHERE t.user_id = '00000000-0000-4000-c000-00000000000a'$q$, 2);

-- profiles
SELECT pg_temp.expect_count('own profile read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-00000000000a'$q$, 1);
SELECT pg_temp.expect_count('profile of a friend read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-00000000000b'$q$, 1);
SELECT pg_temp.expect_count('profile of the sender of a pending request read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-000000000050'$q$, 1);
SELECT pg_temp.expect_count('profile of the receiver of a pending request read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-00000000000d'$q$, 1);
SELECT pg_temp.expect_count('profile of a user who booked a readable wish read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-00000000000f'$q$, 1);
SELECT pg_temp.expect_count('profile of the owner of a public wishlist read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-00000000005e'$q$, 1);
SELECT pg_temp.expect_count('profile of a user with a private wishlist only and no relation not read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-00000000000e'$q$, 0);
SELECT pg_temp.expect_count('profile of a blocked friendship not read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-0000000000b1'$q$, 0);
SELECT pg_temp.expect_count('profile of a rejected friendship not read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-0000000000e2'$q$, 0);
SELECT pg_temp.expect_count('profile of the owner of a private wishlist holding a booked wish read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-0000000000c9'$q$, 1);
SELECT pg_temp.expect_count('same profile not read through users_profiles',
  $q$SELECT count(*) FROM public.users_profiles WHERE id = '00000000-0000-4000-c000-00000000000e'$q$, 0);
SELECT pg_temp.expect_count('same profile found by search_users',
  $q$SELECT count(*) FROM public.search_users('read_n')$q$, 1);

-- As F: no relation with A
SELECT pg_temp.act_as('00000000-0000-4000-c000-00000000000f');
SELECT pg_temp.expect_count('public wish read by a user without relation',
  $q$SELECT count(*) FROM public.wishs WHERE id = 950002$q$, 1);
SELECT pg_temp.expect_count('private wish of the owner not read',
  $q$SELECT count(*) FROM public.wishs WHERE id = 950005$q$, 0);
SELECT pg_temp.expect_count('private wishlist of a user without relation not read by F',
  $q$SELECT count(*) FROM public.wishlists WHERE id = 940001$q$, 0);
SELECT pg_temp.expect_count('private wishlist with a booking not read by a non-booker F',
  $q$SELECT count(*) FROM public.wishlists WHERE id = 940005$q$, 0);
SELECT pg_temp.expect_count('profile of a user who only booked in a private wishlist not read',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-00000000000a'$q$, 0);

-- As P: pending request to A
SELECT pg_temp.act_as('00000000-0000-4000-c000-000000000050');
SELECT pg_temp.expect_count('public wishlist read, private wishlist of the receiver not read',
  $q$SELECT count(*) FROM public.wishlists WHERE id IN (940002, 940001)$q$, 1);
SELECT pg_temp.expect_count('private wishlist with a booking not read by a non-booker P',
  $q$SELECT count(*) FROM public.wishlists WHERE id = 940005$q$, 0);

-- As B: the owner reads everything of their own and the profile of A (a
-- friend, who also booked wish 950005; the booking clause of can_read_profile
-- does not apply here since 940005 has can_owner_see_taken_wish false: it is
-- covered by booking_read_policies.sql)
SELECT pg_temp.act_as('00000000-0000-4000-c000-00000000000b');
SELECT pg_temp.expect_count('own wishlists read by the owner',
  $q$SELECT count(*) FROM public.wishlists WHERE id_owner = '00000000-0000-4000-c000-00000000000b'$q$, 4);
SELECT pg_temp.expect_count('own wishes read by the owner',
  $q$SELECT count(*) FROM public.wishs WHERE wishlist_id BETWEEN 940002 AND 940005$q$, 5);
SELECT pg_temp.expect_count('profile of a friend who booked an own wish read (friendship)',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-c000-00000000000a'$q$, 1);

-- As A: what the app sends, PostgREST turns insert().select() and
-- update().select() into INSERT/UPDATE ... RETURNING, which checks the SELECT
-- policy on the new row (supabase_wishlist_repository, supabase_wish_repository).
SELECT pg_temp.act_as('00000000-0000-4000-c000-00000000000a');
SELECT pg_temp.expect_count('wishlist created with RETURNING',
  $q$WITH r AS (
       INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility)
       VALUES (940101, 'A new private', '00000000-0000-4000-c000-00000000000a', '#FFFFFF',
               '00000000-0000-4000-c000-00000000000a', 'private')
       RETURNING *)
     SELECT count(*) FROM r$q$, 1);
SELECT pg_temp.expect_count('public wishlist created with RETURNING',
  $q$WITH r AS (
       INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility)
       VALUES (940102, 'A new public', '00000000-0000-4000-c000-00000000000a', '#FFFFFF',
               '00000000-0000-4000-c000-00000000000a', 'public')
       RETURNING *)
     SELECT count(*) FROM r$q$, 1);
SELECT pg_temp.expect_count('wishlist updated with RETURNING, turned private',
  $q$WITH r AS (
       UPDATE public.wishlists SET visibility = 'private', name = 'A renamed' WHERE id = 940102
       RETURNING *)
     SELECT count(*) FROM r$q$, 1);
SELECT pg_temp.expect_count('wish created with RETURNING',
  $q$WITH r AS (
       INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by)
       VALUES (950101, 'A new wish', '', 940101, '00000000-0000-4000-c000-00000000000a')
       RETURNING *)
     SELECT count(*) FROM r$q$, 1);
SELECT pg_temp.expect_count('wish updated with RETURNING',
  $q$WITH r AS (
       UPDATE public.wishs SET name = 'A renamed wish' WHERE id = 950101
       RETURNING *)
     SELECT count(*) FROM r$q$, 1);
SELECT pg_temp.expect_count('profile updated with RETURNING',
  $q$WITH r AS (
       UPDATE public.profiles SET pseudo = 'read_a2' WHERE id = '00000000-0000-4000-c000-00000000000a'
       RETURNING *)
     SELECT count(*) FROM r$q$, 1);

ROLLBACK;
