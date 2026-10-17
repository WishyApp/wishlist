-- Privileges of anon and authenticated in the public schema
-- (20261012110000_restrict_anon_privileges).
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

-- postgres functions have no EXECUTE for PUBLIC by default (see the migration):
-- the helpers below are called after switching role. Rolled back with the rest.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

CREATE FUNCTION pg_temp.expect_denied(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: allowed, expected a denial', label;
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'ok   % (denied)', label;
END $$;

CREATE FUNCTION pg_temp.expect_ok(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE NOTICE 'ok   % (allowed)', label;
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

-- Fixtures: A, with a wishlist, a wish and a profile.
INSERT INTO auth.users (id) VALUES ('00000000-0000-4000-c000-00000000000a');
INSERT INTO public.profiles (id, pseudo) VALUES ('00000000-0000-4000-c000-00000000000a', 'anon_test_a');
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility, is_closed) VALUES
  (930001, 'A public', '00000000-0000-4000-c000-00000000000a', '#FFFFFF', '00000000-0000-4000-c000-00000000000a', 'public', false);
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, quantity) VALUES
  (940001, 'A wish', '', 930001, '00000000-0000-4000-c000-00000000000a', 1);

-- Catalog checks, as postgres
DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'v', 'm', 'p', 'f')
     AND a.grantee IN (0, 'anon'::regrole);
  IF n <> 0 THEN
    RAISE EXCEPTION 'FAIL anon or PUBLIC has % table privilege(s) in public', n;
  END IF;

  SELECT count(*) INTO n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p')
     AND a.grantee = 'authenticated'::regrole
     AND a.privilege_type IN ('TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN');
  IF n <> 0 THEN
    RAISE EXCEPTION 'FAIL authenticated has % TRUNCATE/TRIGGER/REFERENCES/MAINTAIN privilege(s) on public tables', n;
  END IF;

  SELECT count(*) INTO n FROM pg_default_acl d, aclexplode(d.defaclacl) a
   WHERE d.defaclrole = 'postgres'::regrole
     AND d.defaclnamespace = 'public'::regnamespace
     AND d.defaclobjtype = 'r'
     AND a.grantee = 'authenticated'::regrole
     AND a.privilege_type IN ('TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN');
  IF n <> 0 THEN
    RAISE EXCEPTION 'FAIL default privileges of postgres grant authenticated TRUNCATE/TRIGGER/REFERENCES/MAINTAIN on new tables';
  END IF;

  SELECT count(*) INTO n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'S'
     AND a.grantee IN (0, 'anon'::regrole, 'authenticated'::regrole);
  IF n <> 0 THEN
    RAISE EXCEPTION 'FAIL anon, authenticated or PUBLIC has % sequence privilege(s) in public', n;
  END IF;

  SELECT count(*) INTO n FROM pg_default_acl d, aclexplode(d.defaclacl) a
   WHERE d.defaclrole = 'postgres'::regrole
     AND d.defaclnamespace = 'public'::regnamespace
     AND d.defaclobjtype = 'S'
     AND a.grantee = 'authenticated'::regrole;
  IF n <> 0 THEN
    RAISE EXCEPTION 'FAIL default privileges of postgres grant authenticated on new sequences';
  END IF;

  -- Functions executable by anon, directly or through PUBLIC
  SELECT count(*) INTO n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND has_function_privilege('anon', p.oid, 'EXECUTE')
     AND p.oid <> 'public.get_email_by_pseudo(text)'::regprocedure;
  IF n <> 0 THEN
    RAISE EXCEPTION 'FAIL anon can execute % public function(s) other than get_email_by_pseudo(text)', n;
  END IF;

  SELECT count(*) INTO n FROM pg_default_acl d, aclexplode(d.defaclacl) a
   WHERE d.defaclrole = 'postgres'::regrole
     AND d.defaclnamespace = 'public'::regnamespace
     AND a.grantee = 'anon'::regrole;
  IF n <> 0 THEN
    RAISE EXCEPTION 'FAIL default privileges of postgres still grant anon (% entries)', n;
  END IF;
  IF to_regprocedure('public.delete_user_account()') IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL public.delete_user_account() still exists';
  END IF;

  -- Procedures are covered too (ALL ROUTINES)
  SELECT count(*) INTO n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'p'
     AND has_function_privilege('anon', p.oid, 'EXECUTE');
  IF n <> 0 THEN
    RAISE EXCEPTION 'FAIL anon can execute % public procedure(s)', n;
  END IF;
  RAISE NOTICE 'ok   catalog: no anon grant left, default privileges cleaned';
END $$;

-- All helpers exist: back to the default privileges of the migration, which the
-- checks below are about.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Objects created by postgres from now on get no privilege for anon, no
-- sequence privilege and no MAINTAIN for authenticated. A function in public
-- is granted to authenticated only; one in extensions keeps EXECUTE for PUBLIC.
CREATE TABLE public.anon_privileges_test_tbl (id int);
CREATE SEQUENCE public.anon_privileges_test_seq;
CREATE FUNCTION public.anon_privileges_test_fn() RETURNS int LANGUAGE sql AS 'SELECT 1';
CREATE FUNCTION extensions.anon_privileges_test_fn() RETURNS int LANGUAGE sql AS 'SELECT 1';
DO $$
BEGIN
  IF has_table_privilege('anon', 'public.anon_privileges_test_tbl', 'SELECT')
     OR has_sequence_privilege('anon', 'public.anon_privileges_test_seq', 'USAGE')
     OR has_sequence_privilege('authenticated', 'public.anon_privileges_test_seq', 'USAGE')
     OR has_table_privilege('authenticated', 'public.anon_privileges_test_tbl', 'MAINTAIN') THEN
    RAISE EXCEPTION 'FAIL a new table or sequence of public is granted to anon, or beyond the app needs to authenticated';
  END IF;
  IF has_function_privilege('anon', 'public.anon_privileges_test_fn()', 'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL anon can execute a new function of public';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.anon_privileges_test_fn()', 'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL authenticated cannot execute a new function of public';
  END IF;
  IF NOT has_function_privilege('anon', 'extensions.anon_privileges_test_fn()', 'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL a new function of extensions is not executable by PUBLIC';
  END IF;
  RAISE NOTICE 'ok   catalog: defaults for new objects';
END $$;
SELECT pg_temp.act_as_anon();
SELECT pg_temp.expect_denied('new table read by anon',
  $q$SELECT * FROM public.anon_privileges_test_tbl$q$);
SELECT pg_temp.expect_denied('new function executed by anon',
  $q$SELECT public.anon_privileges_test_fn()$q$);
RESET ROLE;
DROP TABLE public.anon_privileges_test_tbl;
DROP SEQUENCE public.anon_privileges_test_seq;
DROP FUNCTION public.anon_privileges_test_fn();
DROP FUNCTION extensions.anon_privileges_test_fn();

-- As anon
SELECT pg_temp.act_as_anon();
SELECT pg_temp.expect_denied('anon reads wishlists', $q$SELECT * FROM public.wishlists$q$);
SELECT pg_temp.expect_denied('anon reads wishs', $q$SELECT * FROM public.wishs$q$);
SELECT pg_temp.expect_denied('anon reads profiles', $q$SELECT * FROM public.profiles$q$);
SELECT pg_temp.expect_denied('anon reads friendships', $q$SELECT * FROM public.friendships$q$);
SELECT pg_temp.expect_denied('anon reads wish_taken_by_user', $q$SELECT * FROM public.wish_taken_by_user$q$);
SELECT pg_temp.expect_denied('anon reads user_completed_wishs', $q$SELECT * FROM public.user_completed_wishs$q$);
SELECT pg_temp.expect_denied('anon reads users_profiles', $q$SELECT * FROM public.users_profiles$q$);
SELECT pg_temp.expect_denied('anon inserts a wishlist',
  $q$INSERT INTO public.wishlists (name, id_owner, color, updated_by) VALUES ('x', '00000000-0000-4000-c000-00000000000a', '#FFFFFF', '00000000-0000-4000-c000-00000000000a')$q$);
SELECT pg_temp.expect_denied('anon deletes wishs', $q$DELETE FROM public.wishs$q$);
SELECT pg_temp.expect_denied('anon truncates wishs', $q$TRUNCATE public.wishs$q$);
SELECT pg_temp.expect_denied('anon uses a sequence', $q$SELECT nextval('public.wishs_id_seq')$q$);
SELECT pg_temp.expect_denied('anon executes is_friend_or_friend_of_friend',
  $q$SELECT public.is_friend_or_friend_of_friend('00000000-0000-4000-c000-00000000000a', '00000000-0000-4000-c000-00000000000a')$q$);
SELECT pg_temp.expect_denied('anon executes nb_wishs_by_user',
  $q$SELECT public.nb_wishs_by_user('00000000-0000-4000-c000-00000000000a')$q$);
SELECT pg_temp.expect_denied('anon executes delete_or_archive_wishlist',
  $q$SELECT public.delete_or_archive_wishlist(930001)$q$);
SELECT pg_temp.expect_denied('anon executes restore_completed_wish',
  $q$SELECT public.restore_completed_wish(940001, 930001)$q$);
SELECT pg_temp.expect_denied('anon executes search_users', $q$SELECT * FROM public.search_users('a')$q$);
SELECT pg_temp.expect_denied('anon executes is_wishlist_owner', $q$SELECT public.is_wishlist_owner(930001)$q$);
SELECT pg_temp.expect_denied('anon executes can_book_wish', $q$SELECT public.can_book_wish(940001, 1)$q$);
SELECT pg_temp.expect_ok('anon resolves a pseudo before sign in',
  $q$SELECT public.get_email_by_pseudo('anon_test_a')$q$);

-- As A, the app flows still work
RESET ROLE;
SELECT pg_temp.act_as('00000000-0000-4000-c000-00000000000a');
SELECT pg_temp.expect_ok('authenticated reads wishlists', $q$SELECT * FROM public.wishlists$q$);
SELECT pg_temp.expect_ok('authenticated reads wishs', $q$SELECT * FROM public.wishs$q$);
SELECT pg_temp.expect_ok('authenticated reads profiles', $q$SELECT * FROM public.profiles$q$);
SELECT pg_temp.expect_ok('authenticated reads users_profiles', $q$SELECT * FROM public.users_profiles$q$);
SELECT pg_temp.expect_ok('authenticated reads friendships', $q$SELECT * FROM public.friendships$q$);
SELECT pg_temp.expect_ok('authenticated inserts a wishlist (identity column)',
  $q$INSERT INTO public.wishlists (name, id_owner, color, updated_by) VALUES ('new', '00000000-0000-4000-c000-00000000000a', '#FFFFFF', '00000000-0000-4000-c000-00000000000a')$q$);
SELECT pg_temp.expect_ok('authenticated inserts a wish (identity column)',
  $q$INSERT INTO public.wishs (name, description, wishlist_id, updated_by, quantity) VALUES ('new', '', 930001, '00000000-0000-4000-c000-00000000000a', 1)$q$);
SELECT pg_temp.expect_ok('authenticated updates an own wishlist',
  $q$UPDATE public.wishlists SET name = 'renamed' WHERE id = 930001$q$);
SELECT pg_temp.expect_ok('authenticated executes nb_wishs_by_user',
  $q$SELECT public.nb_wishs_by_user('00000000-0000-4000-c000-00000000000a')$q$);
SELECT pg_temp.expect_ok('authenticated executes search_users', $q$SELECT * FROM public.search_users('anon')$q$);
SELECT pg_temp.expect_ok('authenticated executes get_email_by_pseudo',
  $q$SELECT public.get_email_by_pseudo('anon_test_a')$q$);
SELECT pg_temp.expect_ok('authenticated executes delete_or_archive_wishlist',
  $q$SELECT public.delete_or_archive_wishlist(930001)$q$);
SELECT pg_temp.expect_denied('authenticated truncates wishs', $q$TRUNCATE public.wishs$q$);
SELECT pg_temp.expect_denied('authenticated reindexes wishs', $q$REINDEX TABLE public.wishs$q$);
SELECT pg_temp.expect_denied('authenticated uses a sequence', $q$SELECT nextval('public.wishs_id_seq')$q$);
SELECT pg_temp.expect_denied('authenticated setval', $q$SELECT setval('public.wishs_id_seq', 1)$q$);
SELECT pg_temp.expect_denied('authenticated executes a trigger function',
  $q$SELECT public.update_user_completed_wishs_updated_at()$q$);

ROLLBACK;
