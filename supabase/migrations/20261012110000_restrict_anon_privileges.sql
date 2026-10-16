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

-- 3. Functions. PUBLIC has EXECUTE by default, so it is revoked together with
-- anon, then authenticated is granted back everything: the RPC called by the
-- app and the functions used by policies, which run as the caller.
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- delete_user_account is not called through RPC by the app: AuthService calls
-- the delete-user-account Edge Function, whose source is not in this
-- repository. It deletes auth.uid(), so it only works with the JWT of the
-- user, hence the grant to authenticated (kept from 20261005170000).

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
-- all schemas at once, so the schemas where postgres creates functions that
-- others call are given it back: extensions (CREATE EXTENSION run as
-- postgres). Functions created by postgres in public keep the grants to
-- authenticated and service_role of the default privileges above. The
-- helper functions of supabase-tests/ are granted to PUBLIC by the tests.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA extensions GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

-- Verification: tests in supabase-tests/anon_privileges.sql.
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
