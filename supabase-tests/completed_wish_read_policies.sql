-- Read rule of user_completed_wishs
-- (20261018120000_restrict_completed_wish_reads).
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

-- Functions created by postgres have no EXECUTE for PUBLIC by default
-- (20261012110000_restrict_anon_privileges): the helpers below are called
-- after switching role. Rolled back with the rest.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

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
--   A: acting user, owns a private wishlist and has completed one of its wishes.
--   B: friend of A. Public wishlist, private wishlist, archived public
--      wishlist, archived private wishlist; each holds a wish B completed.
--      A third public wish was completed, then moved to a private wishlist.
--   S: stranger, completed a wish of B's public wishlist, and one of its own
--      private wishlist.
--   Q: stranger, completed a wish of its private wishlist, which A booked.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-e000-00000000000a'),
  ('00000000-0000-4000-e000-00000000000b'),
  ('00000000-0000-4000-e000-00000000005e'),
  ('00000000-0000-4000-e000-0000000000c9');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-e000-00000000000a', 'cw_a'),
  ('00000000-0000-4000-e000-00000000000b', 'cw_b'),
  ('00000000-0000-4000-e000-00000000005e', 'cw_s'),
  ('00000000-0000-4000-e000-0000000000c9', 'cw_q');
INSERT INTO public.friendships (id, requester_id, receiver_id, status) VALUES
  (985001, '00000000-0000-4000-e000-00000000000a', '00000000-0000-4000-e000-00000000000b', 'accepted');
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility, deleted_at) VALUES
  (986001, 'A private',          '00000000-0000-4000-e000-00000000000a', '#FFFFFF', '00000000-0000-4000-e000-00000000000a', 'private', NULL),
  (986002, 'B public',           '00000000-0000-4000-e000-00000000000b', '#FFFFFF', '00000000-0000-4000-e000-00000000000b', 'public',  NULL),
  (986003, 'B private',          '00000000-0000-4000-e000-00000000000b', '#FFFFFF', '00000000-0000-4000-e000-00000000000b', 'private', NULL),
  (986004, 'B public archived',  '00000000-0000-4000-e000-00000000000b', '#FFFFFF', '00000000-0000-4000-e000-00000000000b', 'public',  now()),
  (986005, 'B private archived', '00000000-0000-4000-e000-00000000000b', '#FFFFFF', '00000000-0000-4000-e000-00000000000b', 'private', now()),
  (986006, 'S private',          '00000000-0000-4000-e000-00000000005e', '#FFFFFF', '00000000-0000-4000-e000-00000000005e', 'private', NULL),
  (986007, 'Q private',          '00000000-0000-4000-e000-0000000000c9', '#FFFFFF', '00000000-0000-4000-e000-0000000000c9', 'private', NULL);
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by) VALUES
  (987001, 'A wish',            '', 986001, '00000000-0000-4000-e000-00000000000a'),
  (987002, 'B public wish',     '', 986002, '00000000-0000-4000-e000-00000000000b'),
  (987003, 'B private wish',    '', 986003, '00000000-0000-4000-e000-00000000000b'),
  (987004, 'B archived public wish',  '', 986004, '00000000-0000-4000-e000-00000000000b'),
  (987005, 'B archived private wish', '', 986005, '00000000-0000-4000-e000-00000000000b'),
  (987006, 'B moved wish',      '', 986002, '00000000-0000-4000-e000-00000000000b'),
  (987007, 'S private wish',    '', 986006, '00000000-0000-4000-e000-00000000005e'),
  (987008, 'Q wish booked by A', '', 986007, '00000000-0000-4000-e000-0000000000c9'),
  (987009, 'A wish to complete', '', 986001, '00000000-0000-4000-e000-00000000000a');
INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity) VALUES
  ('00000000-0000-4000-e000-00000000000a', 987001, 986001, 1),
  ('00000000-0000-4000-e000-00000000000b', 987002, 986002, 1),
  ('00000000-0000-4000-e000-00000000000b', 987003, 986003, 1),
  ('00000000-0000-4000-e000-00000000000b', 987004, 986004, 1),
  ('00000000-0000-4000-e000-00000000000b', 987005, 986005, 1),
  ('00000000-0000-4000-e000-00000000000b', 987006, 986002, 1),
  ('00000000-0000-4000-e000-00000000005e', 987002, 986002, 1),
  ('00000000-0000-4000-e000-00000000005e', 987007, 986006, 1),
  ('00000000-0000-4000-e000-0000000000c9', 987008, 986007, 1);
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (987008, '00000000-0000-4000-e000-00000000000a', 1);
-- The wish was moved to a private wishlist after being completed: the row
-- still points to the public wishlist it was completed from.
UPDATE public.wishs SET wishlist_id = 986003 WHERE id = 987006;

-- As A
SELECT pg_temp.act_as('00000000-0000-4000-e000-00000000000a');

SELECT pg_temp.expect_count('own completed wish read',
  $q$SELECT count(*) FROM public.user_completed_wishs WHERE wish_id = 987001$q$, 1);
SELECT pg_temp.expect_count('completed wish of a public wishlist read (friend)',
  $q$SELECT count(*) FROM public.user_completed_wishs
     WHERE user_id = '00000000-0000-4000-e000-00000000000b' AND wish_id = 987002$q$, 1);
SELECT pg_temp.expect_count('completed wish of a public wishlist read (stranger)',
  $q$SELECT count(*) FROM public.user_completed_wishs
     WHERE user_id = '00000000-0000-4000-e000-00000000005e' AND wish_id = 987002$q$, 1);
SELECT pg_temp.expect_count('completed wish of an archived public wishlist read',
  $q$SELECT count(*) FROM public.user_completed_wishs WHERE wish_id = 987004$q$, 1);
SELECT pg_temp.expect_count('completed wish of a private wishlist not read (friend)',
  $q$SELECT count(*) FROM public.user_completed_wishs WHERE wish_id = 987003$q$, 0);
SELECT pg_temp.expect_count('completed wish of an archived private wishlist not read',
  $q$SELECT count(*) FROM public.user_completed_wishs WHERE wish_id = 987005$q$, 0);
SELECT pg_temp.expect_count('completed wish moved to a private wishlist not read',
  $q$SELECT count(*) FROM public.user_completed_wishs WHERE wish_id = 987006$q$, 0);
SELECT pg_temp.expect_count('completed wish of a stranger private wishlist not read',
  $q$SELECT count(*) FROM public.user_completed_wishs WHERE wish_id = 987007$q$, 0);
SELECT pg_temp.expect_count('completed wish A booked read',
  $q$SELECT count(*) FROM public.user_completed_wishs WHERE wish_id = 987008$q$, 1);
-- A reads: its own row, B's public and archived public, S's public, Q's booked.
SELECT pg_temp.expect_count('all rows readable by A',
  $q$SELECT count(*) FROM public.user_completed_wishs$q$, 5);

-- Client write path: insert().select() (INSERT ... RETURNING) on the new row
SELECT pg_temp.expect_count('insert with RETURNING of an own completed wish',
  $q$WITH ins AS (
       INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity)
       VALUES ('00000000-0000-4000-e000-00000000000a', 987009, 986001, 1)
       RETURNING wish_id
     ) SELECT count(*) FROM ins$q$, 1);
-- markAsCompleted reads its own row before updating it
SELECT pg_temp.expect_count('own row read before update',
  $q$SELECT count(*) FROM public.user_completed_wishs
     WHERE user_id = '00000000-0000-4000-e000-00000000000a' AND wish_id = 987009$q$, 1);
SELECT pg_temp.expect_count('update of the own quantity',
  $q$WITH upd AS (
       UPDATE public.user_completed_wishs SET quantity = 2
       WHERE user_id = '00000000-0000-4000-e000-00000000000a' AND wish_id = 987009
       RETURNING 1
     ) SELECT count(*) FROM upd$q$, 1);
SELECT pg_temp.expect_count('delete of an own completed wish',
  $q$WITH del AS (
       DELETE FROM public.user_completed_wishs
       WHERE user_id = '00000000-0000-4000-e000-00000000000a' AND wish_id = 987009
       RETURNING 1
     ) SELECT count(*) FROM del$q$, 1);

-- As S (stranger)
RESET ROLE;
SELECT pg_temp.act_as('00000000-0000-4000-e000-00000000005e');
SELECT pg_temp.expect_count('stranger reads its own rows only, plus public wishlists',
  $q$SELECT count(*) FROM public.user_completed_wishs$q$, 4);
SELECT pg_temp.expect_count('stranger does not read the private wishlist completions of B',
  $q$SELECT count(*) FROM public.user_completed_wishs WHERE wish_id IN (987003, 987005, 987006)$q$, 0);
SELECT pg_temp.expect_count('stranger does not read the completions of A',
  $q$SELECT count(*) FROM public.user_completed_wishs WHERE user_id = '00000000-0000-4000-e000-00000000000a'$q$, 0);

-- No fallback: a wish that cannot be found is not readable (cannot happen
-- through the foreign key, so the helper is called directly).
RESET ROLE;
SELECT pg_temp.act_as('00000000-0000-4000-e000-00000000000a');
-- IS FALSE, not just "not true": the helper answers false, never NULL.
SELECT pg_temp.expect_count('nonexistent wish is not readable',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.can_read_completed_wish(999999) IS FALSE) t$q$, 1);

-- As anon: no access
RESET ROLE;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM 1 FROM public.user_completed_wishs;
  RAISE EXCEPTION 'FAIL anon read of user_completed_wishs allowed';
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'ok   anon cannot read user_completed_wishs';
END $$;

ROLLBACK;
