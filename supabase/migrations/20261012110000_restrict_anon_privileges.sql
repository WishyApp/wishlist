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
-- authenticated keeps its table, sequence and function privileges, except
-- TRUNCATE, TRIGGER and REFERENCES on tables: the app never uses them, and
-- TRUNCATE is not subject to row level security.
-- service_role is left untouched.

-- 1. Tables and views: nothing for anon. authenticated loses the privileges
-- the app does not use. Column privileges granted to authenticated by earlier
-- migrations (friendships.status, user_completed_wishs.quantity) are not
-- affected by revoking table-level TRUNCATE, TRIGGER or REFERENCES.
REVOKE ALL ON TABLE
  public.friendships,
  public.profiles,
  public.users_profiles,
  public.user_completed_wishs,
  public.wish_taken_by_user,
  public.wishlists,
  public.wishs
FROM anon;

REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLE
  public.friendships,
  public.profiles,
  public.user_completed_wishs,
  public.wish_taken_by_user,
  public.wishlists,
  public.wishs
FROM authenticated;

-- 2. Sequences: nothing for anon. authenticated keeps USAGE, needed by the
-- column defaults of inserts.
REVOKE ALL ON SEQUENCE
  public.friendships_id_seq,
  public.wishlists_id_seq,
  public.wishs_id_seq
FROM anon;

-- 3. Functions. PUBLIC has EXECUTE by default, so it is revoked together with
-- anon, then each function is granted to the roles that call it.
--
-- Called by the app (RPC) or by policies, which run as the caller:
REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_friend_or_friend_of_friend(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.nb_wishs_by_user(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_or_archive_wishlist(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.restore_completed_wish(bigint, bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_wishlist_owner(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_book_wish(bigint, bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.search_users(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_friend_or_friend_of_friend(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.nb_wishs_by_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_or_archive_wishlist(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restore_completed_wish(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_wishlist_owner(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_book_wish(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_users(text) TO authenticated;

-- The one function used before sign in.
REVOKE ALL ON FUNCTION public.get_email_by_pseudo(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_email_by_pseudo(text) TO anon, authenticated;

-- Trigger functions: privileges are checked when the trigger is created, not
-- when it fires, so no client role needs EXECUTE.
REVOKE ALL ON FUNCTION public.update_user_metadata() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_user_completed_wishs_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.friendships_before_update() FROM PUBLIC, anon, authenticated;

-- 4. Default privileges of the role running migrations (postgres): tables,
-- sequences and functions created from now on are not granted to anon.
-- authenticated and service_role keep their defaults.
--
-- Default privileges are per creating role. Only those of postgres can be
-- changed here: the ones of supabase_admin, which also grant anon on tables,
-- sequences and functions in public, can only be changed by supabase_admin
-- (permission denied for postgres). They apply to objects created by
-- supabase_admin, not by migrations or the SQL editor.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
-- Same for the table privileges the app does not use (see section 1).
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLES FROM authenticated;

-- Not done: the implicit EXECUTE for PUBLIC on new functions. It can only be
-- removed for all schemas at once (ALTER DEFAULT PRIVILEGES FOR ROLE postgres
-- REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, without IN SCHEMA), which also
-- removes it from helper functions created by the database tests and by
-- other tooling. A new function in public is therefore still executable by
-- anon through PUBLIC until it is revoked explicitly, as the other
-- migrations do. The catalog check in supabase-tests/anon_privileges.sql
-- fails CI if a future migration forgets it:
--   REVOKE ALL ON FUNCTION public.f() FROM PUBLIC, anon;
--   GRANT EXECUTE ON FUNCTION public.f() TO authenticated;


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
