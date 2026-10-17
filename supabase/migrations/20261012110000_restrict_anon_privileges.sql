-- Restrict the privileges of the anon role in the public schema to what a
-- signed-out user needs, and stop granting new objects to anon by default.
--
-- Before: anon had ALL on every table and sequence, EXECUTE on every function
-- (directly and through PUBLIC), and ALTER DEFAULT PRIVILEGES granted ALL to
-- anon on every future table, sequence and function. Row level security was
-- the only barrier.
--
-- Signed-out requests made by the app:
-- - Auth API (sign in, sign up, password reset): GoTrue, no table access.
-- - get_email_by_pseudo(text): resolves a pseudo to an email on sign in.
-- Nothing else, so anon keeps USAGE on the schema (PostgREST needs it to call
-- the function) and EXECUTE on get_email_by_pseudo, and nothing more.
--
-- The revokes apply to everything in the schema, not to a list of objects:
-- an object created by hand on dev or prod, outside the migrations, loses
-- its anon privileges too. What must stay granted is granted back explicitly.
-- A REVOKE only removes what the current role (postgres) may remove: for an
-- object owned by another role (supabase_admin), Postgres only warns. The last
-- section therefore checks the result and fails the migration if anon or
-- PUBLIC still has a privilege.
--
-- authenticated keeps its table and function privileges, except TRUNCATE,
-- TRIGGER, REFERENCES and MAINTAIN (Postgres 17: VACUUM, ANALYZE, REINDEX,
-- CLUSTER, LOCK) on tables, which the app never uses (TRUNCATE is not subject
-- to row level security), and every privilege on sequences: an insert on an
-- identity column calls nextval without checking the caller's privileges on
-- the sequence, while UPDATE would allow setval, which breaks the inserts of
-- every user (duplicate keys).
-- service_role is left untouched.

-- 1. Tables and views: nothing for anon. authenticated loses the privileges
-- the app does not use. Column privileges granted to authenticated by earlier
-- migrations (friendships.status, user_completed_wishs.quantity) are not
-- affected by revoking table-level TRUNCATE, TRIGGER, REFERENCES or MAINTAIN.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES, MAINTAIN ON ALL TABLES IN SCHEMA public FROM authenticated;

-- 2. Sequences: nothing for anon and authenticated. Ids are identity columns
-- (friendships, wishlists, wishs), so inserts do not need any privilege on
-- the sequence.
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;

-- 3. Functions and procedures. PUBLIC has EXECUTE by default, so it is revoked
-- together with anon, then authenticated is granted back everything: the RPC
-- called by the app and the functions used by policies, which run as the
-- caller. ROUTINES covers procedures too, which FUNCTIONS does not.
--
-- delete_user_account is dropped first: nothing calls it. AuthService calls the
-- delete-user-account Edge Function, which uses a service_role client (storage
-- cleanup, then auth.admin.deleteUser) and never this function. Left in place
-- it would delete the account without the storage cleanup as soon as a grant
-- like the one below reached it again.
DROP FUNCTION IF EXISTS public.delete_user_account();

REVOKE ALL ON ALL ROUTINES IN SCHEMA public FROM PUBLIC, anon;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO authenticated;

-- The one function used before sign in.
GRANT EXECUTE ON FUNCTION public.get_email_by_pseudo(text) TO anon;

-- Trigger functions: privileges are checked when the trigger is created, not
-- when it fires, so no client role needs EXECUTE.
REVOKE ALL ON FUNCTION public.update_user_metadata() FROM authenticated;
REVOKE ALL ON FUNCTION public.update_user_completed_wishs_updated_at() FROM authenticated;
REVOKE ALL ON FUNCTION public.friendships_before_update() FROM authenticated;

-- 4. Default privileges of the role running migrations (postgres): tables,
-- sequences and functions created from now on are not granted to anon.
-- authenticated and service_role keep their defaults, except the privileges
-- revoked above.
--
-- Default privileges are per creating role. Only those of postgres can be
-- changed here: the ones of supabase_admin, which also grant anon on tables,
-- sequences and functions in public, can only be changed by supabase_admin
-- (permission denied for postgres). They apply to objects created by
-- supabase_admin, not by migrations or the SQL editor.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
-- Same for the table privileges the app does not use (see section 1).
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE TRUNCATE, TRIGGER, REFERENCES, MAINTAIN ON TABLES FROM authenticated;

-- A new function must not be callable by anon through PUBLIC, including one
-- created by hand in the SQL editor. PUBLIC's EXECUTE can only be removed for
-- all schemas at once. Functions created by postgres in public keep the
-- grants to authenticated and service_role of the default privileges above.
-- The helper functions of supabase-tests/ are granted to PUBLIC by the tests.
--
-- This fails closed: a function that postgres creates later outside public
-- (in a new schema) or that another role must call (for example an auth hook
-- run by supabase_auth_admin) needs an explicit GRANT EXECUTE.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
-- Extension objects are created as supabase_admin (supautils), so the default
-- privileges of postgres do not apply to them: this only keeps PUBLIC's
-- EXECUTE on functions that postgres creates by hand in extensions.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA extensions GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

-- 5. Verification. REVOKE does not fail on an object it cannot change (see the
-- header), so check the result: db push fails visibly on dev and prod if an
-- object of public, typically owned by supabase_admin, still has a privilege
-- for anon or PUBLIC. The default privileges of supabase_admin cannot be
-- changed from here and are not checked, only those of postgres.
DO $$
DECLARE
  n int;
  names text;
BEGIN
  -- Tables, views, sequences (grantee 0 is PUBLIC)
  SELECT count(*), string_agg(DISTINCT c.oid::regclass::text, ', ') INTO n, names
    FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.relnamespace = 'public'::regnamespace
     AND a.grantee IN (0, 'anon'::regrole);
  IF n > 0 THEN
    RAISE EXCEPTION '% table/sequence privilege(s) left for anon or PUBLIC in public: %', n, names;
  END IF;

  -- Functions and procedures, directly or through PUBLIC
  SELECT count(*), string_agg(p.oid::regprocedure::text, ', ') INTO n, names
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND has_function_privilege('anon', p.oid, 'EXECUTE')
     AND p.oid <> 'public.get_email_by_pseudo(text)'::regprocedure;
  IF n > 0 THEN
    RAISE EXCEPTION '% routine(s) in public still executable by anon: %', n, names;
  END IF;

  -- Default privileges of postgres for public
  SELECT count(*) INTO n
    FROM pg_default_acl d, aclexplode(d.defaclacl) a
   WHERE d.defaclrole = 'postgres'::regrole
     AND d.defaclnamespace = 'public'::regnamespace
     AND a.grantee IN (0, 'anon'::regrole);
  IF n > 0 THEN
    RAISE EXCEPTION 'default privileges of postgres in public still grant anon or PUBLIC (% entries)', n;
  END IF;
END $$;

-- Tests: supabase-tests/anon_privileges.sql.
--
-- SELECT grantee, table_name, privilege_type FROM information_schema.role_table_grants
--  WHERE table_schema = 'public' AND grantee IN ('anon', 'PUBLIC');
--   -> no rows
--
-- SELECT routine_name, grantee FROM information_schema.routine_privileges
--  WHERE routine_schema = 'public' AND grantee IN ('anon', 'PUBLIC');
--   -> get_email_by_pseudo / anon only
--
-- SELECT defaclrole::regrole, defaclobjtype, defaclacl FROM pg_default_acl
--  WHERE defaclnamespace = 'public'::regnamespace;
--   -> no anon entry for postgres (supabase_admin entries remain)
--
-- SELECT p.oid::regprocedure FROM pg_proc p
--  WHERE p.pronamespace = 'public'::regnamespace
--    AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
--  ORDER BY 1;
--   -> the functions the app and the policies call (nb_wishs_by_user,
--      delete_or_archive_wishlist, restore_completed_wish, search_users,
--      get_email_by_pseudo, is_friend_or_friend_of_friend, is_wishlist_owner,
--      can_book_wish), and no trigger function
