-- Search users through a function instead of a client-built filter on
-- users_profiles, and drop the email from that view.

-- 1. users_profiles no longer needs auth.users: drop the email and run the
-- view with the caller's privileges, so that the RLS of profiles applies.
-- It stays the single definition of a user row (id, "user", profile).
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
  FROM public.profiles p
  WHERE p.pseudo IS NOT NULL;

REVOKE ALL ON TABLE public.users_profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.users_profiles TO authenticated;


-- 2. search_users: rows of users_profiles whose pseudo contains the query
-- (at least 2 characters, case-insensitive, LIKE wildcards matched
-- literally) or whose email equals it (case-insensitive). Exact pseudo
-- first, then prefix, then alphabetical; 50 rows at most.
--
-- Accepted trade-off: an authenticated user can check whether an exact email
-- has an account, and under which pseudo. Search by full email is wanted;
-- partial email search is not offered for that reason.
CREATE OR REPLACE FUNCTION public.search_users(p_query text)
RETURNS TABLE (id uuid, "user" json, profile json)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT v.id, v."user", v.profile
  FROM public.users_profiles v
  JOIN auth.users u ON u.id = v.id
  CROSS JOIN (SELECT btrim(p_query) AS term) q
  WHERE q.term <> ''
    AND (
      (
        char_length(q.term) >= 2
        AND v.profile->>'pseudo' ILIKE '%' || replace(replace(replace(q.term,
          '\', '\\'), '%', '\%'), '_', '\_') || '%'
      )
      OR lower(u.email) = lower(q.term)
    )
  ORDER BY
    lower(v.profile->>'pseudo') = lower(q.term) DESC,
    starts_with(lower(v.profile->>'pseudo'), lower(q.term)) DESC,
    lower(v.profile->>'pseudo')
  LIMIT 50;
$$;

REVOKE ALL ON FUNCTION public.search_users(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(text) TO authenticated;


-- Verification:
-- SELECT profile->>'pseudo' FROM public.search_users('ali');  -- as authenticated
--   -> "ali" first if it exists, then pseudos starting with "ali", then the
--      others containing it; a single character returns nothing
-- SELECT public.search_users('alice@example.com');
--   -> the matching profile, without email; '@' alone returns nothing
--
-- SELECT reloptions FROM pg_class WHERE oid = 'public.users_profiles'::regclass;
--   -> {security_invoker=true}
