-- get_app_version_policy (20261022120000_app_version_policy).
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

CREATE FUNCTION pg_temp.expect_denied(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: allowed, expected a denial', label;
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'ok   % (denied)', label;
END $$;

CREATE FUNCTION pg_temp.act_as_anon()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
END $$;

CREATE FUNCTION pg_temp.act_as(user_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', user_id::text, true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
END $$;

-- Known values, whatever the current state of the table
UPDATE public.app_versions
   SET min_version = '0.2.0', recommended_version = '0.3.0', update_url = NULL
 WHERE platform = 'ios';
UPDATE public.app_versions
   SET min_version = '0.1.0', recommended_version = '0.10.0',
       update_url = 'https://example.com/android'
 WHERE platform = 'android';

DO $$
BEGIN
  IF (SELECT count(*) FROM public.app_versions WHERE platform IN ('ios', 'android')) <> 2 THEN
    RAISE EXCEPTION 'FAIL ios and android rows are not seeded';
  END IF;
  IF has_table_privilege('anon', 'public.app_versions', 'SELECT')
     OR has_table_privilege('authenticated', 'public.app_versions', 'SELECT')
     OR has_table_privilege('authenticated', 'public.app_versions', 'UPDATE') THEN
    RAISE EXCEPTION 'FAIL anon or authenticated has a privilege on app_versions';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.app_versions'::regclass) THEN
    RAISE EXCEPTION 'FAIL RLS is off on app_versions';
  END IF;
  RAISE NOTICE 'ok   catalog: app_versions seeded, RLS on, no grant';
END $$;

-- As anon, before sign in
SELECT pg_temp.act_as_anon();
DO $$
DECLARE
  r record;
BEGIN
  SELECT * INTO r FROM public.get_app_version_policy('ios');
  IF r.min_version IS DISTINCT FROM '0.2.0'
     OR r.recommended_version IS DISTINCT FROM '0.3.0'
     OR r.update_url IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL anon ios policy: %', r;
  END IF;

  SELECT * INTO r FROM public.get_app_version_policy('android');
  IF r.min_version IS DISTINCT FROM '0.1.0'
     OR r.recommended_version IS DISTINCT FROM '0.10.0'
     OR r.update_url IS DISTINCT FROM 'https://example.com/android' THEN
    RAISE EXCEPTION 'FAIL anon android policy: %', r;
  END IF;

  IF EXISTS (SELECT 1 FROM public.get_app_version_policy('windows')) THEN
    RAISE EXCEPTION 'FAIL unknown platform returned a row';
  END IF;
  IF EXISTS (SELECT 1 FROM public.get_app_version_policy(NULL)) THEN
    RAISE EXCEPTION 'FAIL null platform returned a row';
  END IF;
  RAISE NOTICE 'ok   anon reads the policy of ios and android, nothing for another platform';
END $$;
SELECT pg_temp.expect_denied('anon reads app_versions', $q$SELECT * FROM public.app_versions$q$);
SELECT pg_temp.expect_denied('anon updates app_versions',
  $q$UPDATE public.app_versions SET min_version = '99.0.0'$q$);

-- As a signed-in user
RESET ROLE;
SELECT pg_temp.act_as('00000000-0000-4000-c000-0000000000b1');
DO $$
BEGIN
  IF (SELECT min_version FROM public.get_app_version_policy('ios')) IS DISTINCT FROM '0.2.0' THEN
    RAISE EXCEPTION 'FAIL authenticated cannot read the ios policy';
  END IF;
  RAISE NOTICE 'ok   authenticated reads the policy';
END $$;
SELECT pg_temp.expect_denied('authenticated reads app_versions', $q$SELECT * FROM public.app_versions$q$);
SELECT pg_temp.expect_denied('authenticated updates app_versions',
  $q$UPDATE public.app_versions SET min_version = '99.0.0'$q$);

ROLLBACK;
