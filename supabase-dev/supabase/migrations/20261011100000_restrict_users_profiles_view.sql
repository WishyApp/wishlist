-- Restrict the users_profiles view to the columns the app reads, and resolve
-- the email of a pseudo at sign-in through a dedicated function.

-- 1. users_profiles: id, the user's id and email, the public profile fields.
-- The output columns keep their names and types (id, "user", profile), so
-- the app parses rows as before. The view keeps the owner's privileges to
-- read the email from auth.users: authenticated has no access to that table.
-- Profiles without a pseudo yet (sign-up not finished) are left out: the app
-- requires one to read a profile.
CREATE OR REPLACE VIEW public.users_profiles AS
  SELECT
    u.id,
    json_build_object('id', u.id, 'email', u.email) AS "user",
    json_build_object(
      'id', p.id,
      'pseudo', p.pseudo,
      'avatar_url', p.avatar_url
    ) AS profile
  FROM auth.users u
  JOIN public.profiles p ON p.id = u.id
  WHERE p.pseudo IS NOT NULL;

REVOKE ALL ON TABLE public.users_profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.users_profiles TO authenticated;


-- 2. Sign-in with a pseudo happens before authentication: return the email
-- of an exact pseudo, and nothing else.
CREATE OR REPLACE FUNCTION public.get_email_by_pseudo(p_pseudo text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.email::text
  FROM auth.users u
  JOIN public.profiles p ON p.id = u.id
  WHERE p.pseudo = p_pseudo;
$$;

REVOKE ALL ON FUNCTION public.get_email_by_pseudo(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_email_by_pseudo(text) TO anon, authenticated;


-- Verification:
-- SELECT grantee, privilege_type FROM information_schema.role_table_grants
--  WHERE table_schema = 'public' AND table_name = 'users_profiles'
--  ORDER BY 1, 2;
--   -> authenticated SELECT, plus postgres and service_role; no anon row
--
-- SELECT "user" FROM public.users_profiles LIMIT 1;  -- as authenticated
--   -> {"id": ..., "email": ...}, nothing else from auth.users
--
-- SELECT public.get_email_by_pseudo('<pseudo>');  -- as anon
--   -> the email of that pseudo, NULL if unknown
