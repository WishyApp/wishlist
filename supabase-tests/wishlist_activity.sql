-- get_my_wishlists_last_activity and the updated_at triggers of wishs and
-- wishlists (20261031100000_wishlist_activity_and_year_recap).
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
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'ok   % (denied)', label;
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

-- Fixtures. A owns: empty (931001), wish created later (931002), wish modified
-- later (931003), archived (931004), renamed (931006), gifts received (931007),
-- closed (931008), ended (931009) and still running (931010). B owns a PUBLIC
-- list (931005): the read policies let A see it, so only the owner filter of
-- the function keeps it out of A's result.
-- Wishlists get updated_at = created_at unless the case says otherwise.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-d000-0000000000a1'),
  ('00000000-0000-4000-d000-0000000000b1');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-d000-0000000000a1', 'act_a'),
  ('00000000-0000-4000-d000-0000000000b1', 'act_b');

INSERT INTO public.wishlists
  (id, name, id_owner, color, updated_by, created_at, updated_at, deleted_at, is_closed, end_date, visibility) VALUES
  (931001, 'empty',    '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-01T10:00:00Z', '2026-01-01T10:00:00Z', NULL, false, NULL, 'private'),
  (931002, 'created',  '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-02T10:00:00Z', '2026-01-02T10:00:00Z', NULL, false, NULL, 'private'),
  (931003, 'modified', '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-03T10:00:00Z', '2026-01-03T10:00:00Z', NULL, false, NULL, 'private'),
  (931004, 'archived', '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-04T10:00:00Z', '2026-01-04T10:00:00Z', '2026-06-01T10:00:00Z', false, NULL, 'private'),
  (931005, 'of B',     '00000000-0000-4000-d000-0000000000b1', '#112233', '00000000-0000-4000-d000-0000000000b1', '2026-01-05T10:00:00Z', '2026-01-05T10:00:00Z', NULL, false, NULL, 'public'),
  (931006, 'renamed',  '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-06T10:00:00Z', '2026-06-06T10:00:00Z', NULL, false, NULL, 'private'),
  (931007, 'received', '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-07T10:00:00Z', '2026-01-07T10:00:00Z', NULL, false, NULL, 'private'),
  (931008, 'closed',   '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-08T10:00:00Z', '2026-01-08T10:00:00Z', NULL, true,  NULL, 'private'),
  (931009, 'ended',    '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-09T10:00:00Z', '2026-01-09T10:00:00Z', NULL, false, '2000-01-01T10:00:00Z', 'private'),
  (931010, 'running',  '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-10T10:00:00Z', '2026-01-10T10:00:00Z', NULL, false, '2100-01-01T10:00:00Z', 'private'),
  -- Paris day boundary: 931011 ends today in Paris (00:30 or 01:30 there, but
  -- yesterday 23:30 in UTC: dropping the Paris conversion excludes it),
  -- 931012 ended yesterday in Paris.
  (931011, 'ends today', '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-11T10:00:00Z', '2026-01-11T10:00:00Z', NULL, false,
    (((now() AT TIME ZONE 'Europe/Paris')::date - 1)::text || ' 23:30:00')::timestamp AT TIME ZONE 'UTC', 'private'),
  (931012, 'ended yesterday', '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-12T10:00:00Z', '2026-01-12T10:00:00Z', NULL, false,
    (((now() AT TIME ZONE 'Europe/Paris')::date - 1)::text || ' 12:00:00')::timestamp AT TIME ZONE 'UTC', 'private');

INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, created_at, updated_at) VALUES
  (931101, 'created later',  '', 931002, '00000000-0000-4000-d000-0000000000a1', '2026-03-01T10:00:00Z', '2026-03-01T10:00:00Z'),
  (931102, 'modified later', '', 931003, '00000000-0000-4000-d000-0000000000a1', '2026-02-01T10:00:00Z', '2026-05-01T10:00:00Z'),
  (931103, 'in archive',     '', 931004, '00000000-0000-4000-d000-0000000000a1', '2026-07-01T10:00:00Z', '2026-07-01T10:00:00Z'),
  (931104, 'of B',           '', 931005, '00000000-0000-4000-d000-0000000000b1', '2026-08-01T10:00:00Z', '2026-08-01T10:00:00Z'),
  (931105, 'received gift',  '', 931007, '00000000-0000-4000-d000-0000000000a1', '2026-01-08T10:00:00Z', '2026-01-08T10:00:00Z'),
  -- written by a device whose clock is in the future: capped at now()
  (931106, 'from the future', '', 931010, '00000000-0000-4000-d000-0000000000a1', '2026-01-10T11:00:00Z', '2100-01-01T00:00:00Z');
INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, created_at, updated_at) VALUES
  ('00000000-0000-4000-d000-0000000000a1', 931105, 931007, '2026-04-01T10:00:00Z', '2026-04-02T10:00:00Z');

-- As A
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000a1');
DO $$
DECLARE
  got text;
BEGIN
  SELECT string_agg(wishlist_id || '=' ||
           CASE WHEN last_activity_at = now() THEN 'now'
                ELSE (last_activity_at AT TIME ZONE 'UTC')::date::text END,
           ',' ORDER BY wishlist_id)
    INTO got FROM public.get_my_wishlists_last_activity();
  IF got IS DISTINCT FROM
     '931001=2026-01-01,931002=2026-03-01,931003=2026-05-01,931006=2026-06-06,931007=2026-04-02,931010=now,931011=2026-01-11' THEN
    RAISE EXCEPTION 'FAIL last activity of A: %', got;
  END IF;
  RAISE NOTICE 'ok   last activity: creation, wish created or modified, list edited, gift received; a future device clock capped at now(); archived, closed, ended (Paris day) and foreign lists absent';
END $$;

-- As B: only B's list
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000b1');
DO $$
DECLARE
  got text;
BEGIN
  SELECT string_agg(wishlist_id || '=' || (last_activity_at AT TIME ZONE 'UTC')::date, ',')
    INTO got FROM public.get_my_wishlists_last_activity();
  IF got IS DISTINCT FROM '931005=2026-08-01' THEN
    RAISE EXCEPTION 'FAIL last activity of B: %', got;
  END IF;
  RAISE NOTICE 'ok   B only sees own list';
END $$;

-- Signed in without a user id: nothing
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000b1');
SELECT set_config('request.jwt.claim.sub', '', true), set_config('request.jwt.claims', '{"role":"authenticated"}', true);
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.get_my_wishlists_last_activity()) THEN
    RAISE EXCEPTION 'FAIL a null auth.uid() gets rows';
  END IF;
  RAISE NOTICE 'ok   null auth.uid() gets nothing';
END $$;

-- anon is refused
SELECT pg_temp.act_as_anon();
SELECT pg_temp.expect_denied('anon executes get_my_wishlists_last_activity',
  $q$SELECT * FROM public.get_my_wishlists_last_activity()$q$);
RESET ROLE;

-- Trigger of wishs: updated_at is set by the server, whatever the client sends,
-- and a move (restore_completed_wish) counts. updated_by is left alone.
UPDATE public.wishs SET name = 'renamed', updated_at = '2000-01-01T00:00:00Z' WHERE id = 931101;
UPDATE public.wishs SET wishlist_id = 931010 WHERE id = 931102;
DO $$
BEGIN
  IF (SELECT updated_at FROM public.wishs WHERE id = 931101) <> now() THEN
    RAISE EXCEPTION 'FAIL wishs.updated_at is not set by the server on edit';
  END IF;
  IF (SELECT updated_at FROM public.wishs WHERE id = 931102) <> now() THEN
    RAISE EXCEPTION 'FAIL wishs.updated_at is not set by the server on move';
  END IF;
  IF (SELECT updated_by FROM public.wishs WHERE id = 931101)
     <> '00000000-0000-4000-d000-0000000000a1' THEN
    RAISE EXCEPTION 'FAIL wishs.updated_by changed';
  END IF;
  RAISE NOTICE 'ok   wishs.updated_at set by the server, updated_by untouched';
END $$;

-- Trigger of wishlists: a reorder keeps updated_at whatever the client sends,
-- any other edit sets it.
UPDATE public.wishlists
  SET "order" = 7, updated_at = now(), updated_by = '00000000-0000-4000-d000-0000000000b1'
  WHERE id = 931001;
UPDATE public.wishlists SET name = 'renamed again', "order" = 8 WHERE id = 931002;
UPDATE public.wishlists SET visibility = 'public' WHERE id = 931003;
DO $$
BEGIN
  IF (SELECT updated_at FROM public.wishlists WHERE id = 931001) <> '2026-01-01T10:00:00Z' THEN
    RAISE EXCEPTION 'FAIL a reorder changed wishlists.updated_at';
  END IF;
  IF (SELECT updated_by FROM public.wishlists WHERE id = 931001)
     <> '00000000-0000-4000-d000-0000000000b1' THEN
    RAISE EXCEPTION 'FAIL the trigger of wishlists touched updated_by';
  END IF;
  IF (SELECT updated_at FROM public.wishlists WHERE id = 931002) <> now() THEN
    RAISE EXCEPTION 'FAIL a rename did not set wishlists.updated_at';
  END IF;
  IF (SELECT updated_at FROM public.wishlists WHERE id = 931003) <> now() THEN
    RAISE EXCEPTION 'FAIL a visibility change did not set wishlists.updated_at';
  END IF;
  RAISE NOTICE 'ok   wishlists.updated_at: reorder ignored, other edits counted';
END $$;

ROLLBACK;
