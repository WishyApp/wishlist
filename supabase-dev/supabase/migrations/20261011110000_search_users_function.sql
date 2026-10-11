-- Search users through a function instead of a client-built filter on
-- users_profiles, then drop the email from that view.

-- 1. search_users: pseudo contains the query (case-insensitive, LIKE
-- wildcards in the query are matched literally), or email equals it
-- (case-insensitive). Rows have the shape of users_profiles, without email.
CREATE OR REPLACE FUNCTION public.search_users(p_query text)
RETURNS TABLE (id uuid, "user" json, profile json)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p.id,
    json_build_object('id', p.id),
    json_build_object(
      'id', p.id,
      'pseudo', p.pseudo,
      'avatar_url', p.avatar_url
    )
  FROM public.profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE btrim(p_query) <> ''
    AND (
      p.pseudo ILIKE '%' || replace(replace(replace(btrim(p_query),
        '\', '\\'), '%', '\%'), '_', '\_') || '%'
      OR lower(u.email) = lower(btrim(p_query))
    );
$$;

REVOKE ALL ON FUNCTION public.search_users(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(text) TO authenticated;


-- 2. users_profiles no longer needs auth.users: drop the email and run the
-- view with the caller's privileges, so that the RLS of profiles applies.
CREATE OR REPLACE VIEW public.users_profiles
  WITH (security_invoker = true)
AS
  SELECT
    p.id,
    json_build_object('id', p.id) AS "user",
    json_build_object(
      'id', p.id,
      'pseudo', p.pseudo,
      'avatar_url', p.avatar_url
    ) AS profile
  FROM public.profiles p;

REVOKE ALL ON TABLE public.users_profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.users_profiles TO authenticated;


-- Verification:
-- SELECT public.search_users('ali');            -- as authenticated
--   -> profiles whose pseudo contains "ali"
-- SELECT public.search_users('alice@example.com');
--   -> the matching profile, without email; '@' alone returns nothing
--
-- SELECT reloptions FROM pg_class WHERE oid = 'public.users_profiles'::regclass;
--   -> {security_invoker=true}
