-- get_my_wishlists_last_activity (20261031100000_wishlist_activity_and_year_recap)
-- and the year_recap row of home_cards.
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

-- Fixtures. A owns four wishlists: empty, one wish created later, one wish
-- modified later, and an archived one. B owns one.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-d000-0000000000a1'),
  ('00000000-0000-4000-d000-0000000000b1');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-d000-0000000000a1', 'act_a'),
  ('00000000-0000-4000-d000-0000000000b1', 'act_b');

INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, created_at, updated_at, deleted_at) VALUES
  (931001, 'empty',    '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-01T10:00:00Z', '2026-09-01T10:00:00Z', NULL),
  (931002, 'created',  '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-02T10:00:00Z', '2026-09-02T10:00:00Z', NULL),
  (931003, 'modified', '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-03T10:00:00Z', '2026-09-03T10:00:00Z', NULL),
  (931004, 'archived', '00000000-0000-4000-d000-0000000000a1', '#112233', '00000000-0000-4000-d000-0000000000a1', '2026-01-04T10:00:00Z', '2026-09-04T10:00:00Z', '2026-06-01T10:00:00Z'),
  (931005, 'of B',     '00000000-0000-4000-d000-0000000000b1', '#112233', '00000000-0000-4000-d000-0000000000b1', '2026-01-05T10:00:00Z', '2026-09-05T10:00:00Z', NULL);

INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, created_at, updated_at) VALUES
  (931101, 'created later',  '', 931002, '00000000-0000-4000-d000-0000000000a1', '2026-03-01T10:00:00Z', '2026-03-01T10:00:00Z'),
  (931102, 'modified later', '', 931003, '00000000-0000-4000-d000-0000000000a1', '2026-02-01T10:00:00Z', '2026-05-01T10:00:00Z'),
  (931103, 'in archive',     '', 931004, '00000000-0000-4000-d000-0000000000a1', '2026-07-01T10:00:00Z', '2026-07-01T10:00:00Z'),
  (931104, 'of B',           '', 931005, '00000000-0000-4000-d000-0000000000b1', '2026-08-01T10:00:00Z', '2026-08-01T10:00:00Z');

-- As A
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000a1');
DO $$
DECLARE
  got text;
BEGIN
  SELECT string_agg(wishlist_id || '=' || (last_activity_at AT TIME ZONE 'UTC')::date, ',' ORDER BY wishlist_id)
    INTO got FROM public.get_my_wishlists_last_activity();
  IF got IS DISTINCT FROM '931001=2026-01-01,931002=2026-03-01,931003=2026-05-01' THEN
    RAISE EXCEPTION 'FAIL last activity of A: %', got;
  END IF;
  RAISE NOTICE 'ok   last activity: empty = creation, wish created, wish modified; archived and foreign lists absent';
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

-- anon is refused
SELECT pg_temp.act_as_anon();
SELECT pg_temp.expect_denied('anon executes get_my_wishlists_last_activity',
  $q$SELECT * FROM public.get_my_wishlists_last_activity()$q$);
RESET ROLE;

-- year_recap seed
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.home_cards
    WHERE key = 'year_recap' AND kind = 'computed' AND priority = 28
      AND params->>'month' = '12'
  ) THEN
    RAISE EXCEPTION 'FAIL year_recap is not seeded as expected';
  END IF;
  RAISE NOTICE 'ok   year_recap seeded (priority 28, month 12)';
END $$;

ROLLBACK;
