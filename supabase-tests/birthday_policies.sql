-- Rules of profile_birthdays (20261023120000_add_profile_birthdays).
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
EXCEPTION WHEN insufficient_privilege OR check_violation OR not_null_violation THEN
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

CREATE FUNCTION pg_temp.act_as_anon()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
END $$;

-- Fixtures. A owns a birthday.
-- G sent a request to A that A rejected, A blocked H. B is an accepted friend of A (B asked), C an
-- accepted friend of A (A asked), D asked A and is pending, E received a
-- request from A and is pending, F is a stranger.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-d000-00000000000a'),
  ('00000000-0000-4000-d000-00000000000b'),
  ('00000000-0000-4000-d000-00000000000c'),
  ('00000000-0000-4000-d000-00000000000d'),
  ('00000000-0000-4000-d000-00000000000e'),
  ('00000000-0000-4000-d000-00000000000f'),
  ('00000000-0000-4000-d000-000000000010'),
  ('00000000-0000-4000-d000-000000000011');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-d000-00000000000a', 'bday_a'),
  ('00000000-0000-4000-d000-00000000000b', 'bday_b'),
  ('00000000-0000-4000-d000-00000000000c', 'bday_c'),
  ('00000000-0000-4000-d000-00000000000d', 'bday_d'),
  ('00000000-0000-4000-d000-00000000000e', 'bday_e'),
  ('00000000-0000-4000-d000-00000000000f', 'bday_f'),
  ('00000000-0000-4000-d000-000000000010', 'bday_g'),
  ('00000000-0000-4000-d000-000000000011', 'bday_h');
INSERT INTO public.friendships (id, requester_id, receiver_id, status) VALUES
  (921001, '00000000-0000-4000-d000-00000000000b', '00000000-0000-4000-d000-00000000000a', 'accepted'),
  (921002, '00000000-0000-4000-d000-00000000000a', '00000000-0000-4000-d000-00000000000c', 'accepted'),
  (921003, '00000000-0000-4000-d000-00000000000d', '00000000-0000-4000-d000-00000000000a', 'pending'),
  (921004, '00000000-0000-4000-d000-00000000000a', '00000000-0000-4000-d000-00000000000e', 'pending'),
  (921005, '00000000-0000-4000-d000-000000000010', '00000000-0000-4000-d000-00000000000a', 'rejected'),
  (921006, '00000000-0000-4000-d000-00000000000a', '00000000-0000-4000-d000-000000000011', 'blocked');

-- As A, the owner
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000a');
SELECT pg_temp.expect_rows('owner inserts own birthday',
  $q$INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES ('00000000-0000-4000-d000-00000000000a', 3, 12)$q$, 1);
SELECT pg_temp.expect_rows('owner reads own birthday',
  $q$SELECT * FROM public.profile_birthdays WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 1);
SELECT pg_temp.expect_rows('owner updates own birthday',
  $q$UPDATE public.profile_birthdays SET month = 4, day = 30 WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 1);
SELECT pg_temp.expect_denied('owner hands the row to someone else',
  $q$UPDATE public.profile_birthdays SET profile_id = '00000000-0000-4000-d000-00000000000f' WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$);
SELECT pg_temp.expect_denied('owner inserts a birthday for someone else',
  $q$INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES ('00000000-0000-4000-d000-00000000000f', 3, 12)$q$);
SELECT pg_temp.expect_rows('owner accepts February 29',
  $q$UPDATE public.profile_birthdays SET month = 2, day = 29 WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 1);
SELECT pg_temp.expect_denied('April 31 rejected',
  $q$UPDATE public.profile_birthdays SET month = 4, day = 31 WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$);
SELECT pg_temp.expect_denied('February 30 rejected',
  $q$UPDATE public.profile_birthdays SET month = 2, day = 30 WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$);
SELECT pg_temp.expect_denied('month 13 rejected',
  $q$UPDATE public.profile_birthdays SET month = 13, day = 1 WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$);
SELECT pg_temp.expect_denied('month 0 rejected',
  $q$UPDATE public.profile_birthdays SET month = 0, day = 1 WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$);
SELECT pg_temp.expect_denied('day 0 rejected',
  $q$UPDATE public.profile_birthdays SET month = 1, day = 0 WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$);
SELECT pg_temp.expect_rows('owner back to a regular date',
  $q$UPDATE public.profile_birthdays SET month = 3, day = 12 WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 1);

-- As B and C, accepted friends (B sent the request, A sent it to C)
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000b');
SELECT pg_temp.expect_rows('friend who sent the request reads the birthday',
  $q$SELECT * FROM public.profile_birthdays WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 1);
SELECT pg_temp.expect_rows('friend updates the birthday of another',
  $q$UPDATE public.profile_birthdays SET day = 1 WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 0);
SELECT pg_temp.expect_rows('friend deletes the birthday of another',
  $q$DELETE FROM public.profile_birthdays WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 0);
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000c');
SELECT pg_temp.expect_rows('friend who received the request reads the birthday',
  $q$SELECT * FROM public.profile_birthdays WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 1);

-- As D (pending requester), E (pending receiver) and F (stranger)
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000d');
SELECT pg_temp.expect_rows('pending requester reads nothing',
  $q$SELECT * FROM public.profile_birthdays$q$, 0);
SELECT pg_temp.expect_rows('pending requester updates nothing',
  $q$UPDATE public.profile_birthdays SET day = 1$q$, 0);
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000e');
SELECT pg_temp.expect_rows('pending receiver reads nothing',
  $q$SELECT * FROM public.profile_birthdays$q$, 0);
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000f');
SELECT pg_temp.expect_rows('stranger reads nothing',
  $q$SELECT * FROM public.profile_birthdays$q$, 0);
SELECT pg_temp.expect_rows('stranger deletes nothing',
  $q$DELETE FROM public.profile_birthdays$q$, 0);

-- Rejected and blocked friendships give no access
SELECT pg_temp.act_as('00000000-0000-4000-d000-000000000010');
SELECT pg_temp.expect_rows('rejected requester reads nothing',
  $q$SELECT * FROM public.profile_birthdays$q$, 0);
SELECT pg_temp.act_as('00000000-0000-4000-d000-000000000011');
SELECT pg_temp.expect_rows('blocked user reads nothing',
  $q$SELECT * FROM public.profile_birthdays$q$, 0);

-- Nobody writes the row of another user: friends, pending users, strangers
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000b');
SELECT pg_temp.expect_denied('friend inserts a row for the owner',
  $q$INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES ('00000000-0000-4000-d000-00000000000a', 5, 5)$q$);
SELECT pg_temp.expect_denied('friend upserts the row of the owner',
  $q$INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES ('00000000-0000-4000-d000-00000000000a', 5, 5) ON CONFLICT (profile_id) DO UPDATE SET month = 5, day = 5$q$);
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000e');
SELECT pg_temp.expect_rows('pending receiver updates nothing',
  $q$UPDATE public.profile_birthdays SET day = 1$q$, 0);
SELECT pg_temp.expect_rows('pending receiver deletes nothing',
  $q$DELETE FROM public.profile_birthdays$q$, 0);
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000f');
SELECT pg_temp.expect_denied('stranger upserts the row of the owner',
  $q$INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES ('00000000-0000-4000-d000-00000000000a', 5, 5) ON CONFLICT (profile_id) DO UPDATE SET month = 5, day = 5$q$);
SELECT pg_temp.expect_rows('stranger updates nothing',
  $q$UPDATE public.profile_birthdays SET day = 1$q$, 0);
RESET ROLE;
SELECT pg_temp.expect_rows('row of the owner untouched',
  $q$SELECT * FROM public.profile_birthdays WHERE profile_id = '00000000-0000-4000-d000-00000000000a' AND month = 3 AND day = 12$q$, 1);

-- The upsert of the app, as the owner (insert, then conflict), on a user
-- without a row first
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000f');
SELECT pg_temp.expect_rows('owner upsert creates the row',
  $q$INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES ('00000000-0000-4000-d000-00000000000f', 7, 14) ON CONFLICT (profile_id) DO UPDATE SET month = EXCLUDED.month, day = EXCLUDED.day$q$, 1);
SELECT pg_temp.expect_rows('owner upsert updates the row',
  $q$INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES ('00000000-0000-4000-d000-00000000000f', 8, 15) ON CONFLICT (profile_id) DO UPDATE SET month = EXCLUDED.month, day = EXCLUDED.day$q$, 1);
SELECT pg_temp.expect_rows('owner reads the upserted row',
  $q$SELECT * FROM public.profile_birthdays WHERE month = 8 AND day = 15$q$, 1);
SELECT pg_temp.expect_denied('NULL month rejected',
  $q$UPDATE public.profile_birthdays SET month = NULL$q$);
SELECT pg_temp.expect_denied('NULL day rejected',
  $q$UPDATE public.profile_birthdays SET day = NULL$q$);

-- Access follows the friendship: it goes away with it
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000b');
SELECT pg_temp.expect_rows('friend still reads the birthday',
  $q$SELECT * FROM public.profile_birthdays WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 1);
RESET ROLE;
UPDATE public.friendships SET status = 'rejected' WHERE id = 921001;
DELETE FROM public.friendships WHERE id = 921002;
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000b');
SELECT pg_temp.expect_rows('friendship moved off accepted removes access',
  $q$SELECT * FROM public.profile_birthdays WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 0);
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000c');
SELECT pg_temp.expect_rows('deleted friendship removes access',
  $q$SELECT * FROM public.profile_birthdays WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 0);
RESET ROLE;

-- Function attributes of the helper: SECURITY DEFINER, STABLE, pinned search_path
DO $$
DECLARE
  f pg_proc%ROWTYPE;
BEGIN
  SELECT * INTO f FROM pg_proc WHERE oid = 'public.can_read_birthday(uuid)'::regprocedure;
  IF NOT f.prosecdef THEN
    RAISE EXCEPTION 'FAIL can_read_birthday is not SECURITY DEFINER';
  END IF;
  IF f.provolatile <> 's' THEN
    RAISE EXCEPTION 'FAIL can_read_birthday is not STABLE';
  END IF;
  IF f.proconfig IS NULL OR NOT ('search_path=""' = ANY (f.proconfig)) THEN
    RAISE EXCEPTION 'FAIL can_read_birthday does not pin search_path to empty (%)', f.proconfig;
  END IF;
  RAISE NOTICE 'ok   can_read_birthday attributes';
END $$;

-- The pair lookup helper: stable, pinned search_path, and not executable by
-- anon, authenticated or PUBLIC (it tells the friendship status of any pair).
DO $$
DECLARE
  f pg_proc;
BEGIN
  SELECT * INTO f FROM pg_proc
   WHERE oid = 'public.friendship_status_between(uuid, uuid)'::regprocedure;
  IF f.provolatile <> 's' THEN
    RAISE EXCEPTION 'FAIL friendship_status_between is not STABLE';
  END IF;
  IF f.proconfig IS NULL OR NOT ('search_path=""' = ANY (f.proconfig)) THEN
    RAISE EXCEPTION 'FAIL friendship_status_between does not pin search_path to empty (%)', f.proconfig;
  END IF;
  IF has_function_privilege('anon', f.oid, 'EXECUTE')
     OR has_function_privilege('authenticated', f.oid, 'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL friendship_status_between is executable by anon or authenticated';
  END IF;
  RAISE NOTICE 'ok   friendship_status_between attributes and privileges';
END $$;

-- As anon
SELECT pg_temp.act_as_anon();
SELECT pg_temp.expect_denied('anon reads birthdays', $q$SELECT * FROM public.profile_birthdays$q$);
SELECT pg_temp.expect_denied('anon inserts a birthday',
  $q$INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES ('00000000-0000-4000-d000-00000000000f', 3, 12)$q$);
SELECT pg_temp.expect_denied('anon updates birthdays', $q$UPDATE public.profile_birthdays SET day = 1$q$);
SELECT pg_temp.expect_denied('anon deletes birthdays', $q$DELETE FROM public.profile_birthdays$q$);
SELECT pg_temp.expect_denied('anon executes can_read_birthday',
  $q$SELECT public.can_read_birthday('00000000-0000-4000-d000-00000000000a')$q$);
SELECT pg_temp.expect_denied('anon executes friendship_status_between',
  $q$SELECT public.friendship_status_between('00000000-0000-4000-d000-00000000000a', '00000000-0000-4000-d000-00000000000b')$q$);

-- As a signed-in user: the helper tells nothing about other pairs
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000a');
SELECT pg_temp.expect_denied('authenticated executes friendship_status_between',
  $q$SELECT public.friendship_status_between('00000000-0000-4000-d000-00000000000a', '00000000-0000-4000-d000-00000000000b')$q$);
RESET ROLE;

-- The owner deletes the birthday, then it is gone for the friends too
SELECT pg_temp.act_as('00000000-0000-4000-d000-00000000000a');
SELECT pg_temp.expect_rows('owner deletes own birthday',
  $q$DELETE FROM public.profile_birthdays WHERE profile_id = '00000000-0000-4000-d000-00000000000a'$q$, 1);
SELECT pg_temp.expect_rows('owner reads nothing after deleting',
  $q$SELECT * FROM public.profile_birthdays$q$, 0);

ROLLBACK;
