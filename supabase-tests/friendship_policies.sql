-- Write rules of friendships (20261011120000_restrict_friendship_writes).
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

-- Functions created by postgres have no EXECUTE for PUBLIC by default
-- (20261012110000_restrict_anon_privileges): the helpers below are called
-- after switching role. Rolled back with the rest.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

CREATE FUNCTION pg_temp.expect_denied(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: allowed, expected a denial', label;
EXCEPTION WHEN insufficient_privilege OR unique_violation THEN
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

CREATE FUNCTION pg_temp.act_as(user_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', user_id::text, true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
END $$;

-- Fixtures: A, B, C; a pending request from B to C.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-b000-00000000000a'),
  ('00000000-0000-4000-b000-00000000000b'),
  ('00000000-0000-4000-b000-00000000000c');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-b000-00000000000a', 'friend_a'),
  ('00000000-0000-4000-b000-00000000000b', 'friend_b'),
  ('00000000-0000-4000-b000-00000000000c', 'friend_c');
INSERT INTO public.friendships (id, requester_id, receiver_id, status, updated_at) VALUES
  (920001, '00000000-0000-4000-b000-00000000000b', '00000000-0000-4000-b000-00000000000c', 'pending', now() - interval '1 day');

-- As A
SELECT pg_temp.act_as('00000000-0000-4000-b000-00000000000a');
SELECT pg_temp.expect_denied('friendship inserted in the name of another user',
  $q$INSERT INTO public.friendships (requester_id, receiver_id, status) VALUES ('00000000-0000-4000-b000-00000000000b', '00000000-0000-4000-b000-00000000000a', 'pending')$q$);
SELECT pg_temp.expect_denied('request inserted already accepted',
  $q$INSERT INTO public.friendships (requester_id, receiver_id, status) VALUES ('00000000-0000-4000-b000-00000000000a', '00000000-0000-4000-b000-00000000000b', 'accepted')$q$);
SELECT pg_temp.expect_denied('request sent to oneself',
  $q$INSERT INTO public.friendships (requester_id, receiver_id, status) VALUES ('00000000-0000-4000-b000-00000000000a', '00000000-0000-4000-b000-00000000000a', 'pending')$q$);
SELECT pg_temp.expect_denied('request of others taken over by rewriting receiver_id',
  $q$UPDATE public.friendships SET receiver_id = '00000000-0000-4000-b000-00000000000a' WHERE id = 920001$q$);
SELECT pg_temp.expect_rows('request of others accepted',
  $q$UPDATE public.friendships SET status = 'accepted' WHERE id = 920001$q$, 0);
SELECT pg_temp.expect_rows('request sent to B',
  $q$INSERT INTO public.friendships (id, requester_id, receiver_id, status) VALUES (920002, '00000000-0000-4000-b000-00000000000a', '00000000-0000-4000-b000-00000000000b', 'pending')$q$, 1);
SELECT pg_temp.expect_rows('own request accepted by its requester',
  $q$UPDATE public.friendships SET status = 'accepted' WHERE id = 920002$q$, 0);

-- As B
SELECT pg_temp.act_as('00000000-0000-4000-b000-00000000000b');
SELECT pg_temp.expect_denied('second request for the same pair, in the other direction',
  $q$INSERT INTO public.friendships (requester_id, receiver_id, status) VALUES ('00000000-0000-4000-b000-00000000000b', '00000000-0000-4000-b000-00000000000a', 'pending')$q$);
SELECT pg_temp.expect_denied('request from A set to another status than accepted',
  $q$UPDATE public.friendships SET status = 'blocked' WHERE id = 920002$q$);
SELECT pg_temp.expect_denied('requester_id of the request from A rewritten',
  $q$UPDATE public.friendships SET requester_id = '00000000-0000-4000-b000-00000000000c' WHERE id = 920002$q$);
SELECT pg_temp.expect_rows('request from A accepted',
  $q$UPDATE public.friendships SET status = 'accepted' WHERE id = 920002$q$, 1);
SELECT pg_temp.expect_rows('accepted friendship set back to pending',
  $q$UPDATE public.friendships SET status = 'pending' WHERE id = 920002$q$, 0);

-- As C: accepting refreshes updated_at
SELECT pg_temp.act_as('00000000-0000-4000-b000-00000000000c');
SELECT pg_temp.expect_rows('request from B accepted',
  $q$UPDATE public.friendships SET status = 'accepted' WHERE id = 920001$q$, 1);
DO $$
BEGIN
  IF (SELECT updated_at < now() - interval '1 hour' FROM public.friendships WHERE id = 920001) THEN
    RAISE EXCEPTION 'FAIL updated_at not refreshed on update';
  END IF;
  RAISE NOTICE 'ok   updated_at refreshed on update';
END $$;

-- As A again: deleting the friendship
SELECT pg_temp.act_as('00000000-0000-4000-b000-00000000000a');
SELECT pg_temp.expect_rows('friendship with B removed',
  $q$DELETE FROM public.friendships WHERE id = 920002$q$, 1);

-- As postgres (all privileges): the trigger alone rejects a change of
-- requester_id or receiver_id, should the column privilege be lost.
RESET ROLE;
SELECT pg_temp.expect_denied('receiver_id rewritten with all privileges',
  $q$UPDATE public.friendships SET receiver_id = '00000000-0000-4000-b000-00000000000a' WHERE id = 920001$q$);

ROLLBACK;
