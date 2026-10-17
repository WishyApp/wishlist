-- Restrict SELECT on wishlists, wishs and profiles: a private wishlist is
-- readable by its owner only.
--
-- - wishlists: a public wishlist is readable by any signed-in user (the app
--   shares wishlist links with anyone), archived or not: the app filters
--   archived wishlists itself. A private wishlist is readable by its owner
--   only, plus by a user who booked one of its wishes, so that the booked
--   wishes screen keeps showing its name and owner after the wishlist turned
--   private.
-- - wishs: same rule through the wishlist, and a user reads the wishes they
--   booked.
-- - profiles: a user reads their own profile, the profiles of the users they
--   share a friendship (pending or accepted) with, the owners of the public
--   wishlists and of the wishlists holding a wish they booked (the wishlist
--   and wish screens display them), and the users who booked a wish they can
--   read (the "booked by" display). Searching users and signing in with a
--   pseudo go through SECURITY DEFINER functions and are not affected, so a
--   pseudo and an avatar stay findable: the rule keeps the other profiles
--   out of a plain SELECT.
--
-- Booking is unchanged: can_book_wish (SECURITY INVOKER) reads wishs under
-- these policies, and requires a public wishlist anyway.
--
-- The lookups across tables live in SECURITY DEFINER functions, so that the
-- policies of wishlists, wishs and wish_taken_by_user never evaluate each
-- other.

-- 1. Shared rules. SECURITY DEFINER with a pinned search_path: they read
-- wishlists, wishs, wish_taken_by_user and friendships without going through
-- their policies. They only answer about the current user (auth.uid()).

-- The current user reads the wish: it is in one of their wishlists or in a
-- public wishlist, or they booked it.
CREATE OR REPLACE FUNCTION public.can_read_wish(p_wish_id bigint, p_wishlist_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.wishlists wl
    WHERE wl.id = p_wishlist_id
      AND (
        wl.id_owner = (SELECT auth.uid())
        OR wl.visibility = 'public'
      )
  )
  OR EXISTS (
    SELECT 1
    FROM public.wish_taken_by_user t
    WHERE t.wish_id = p_wish_id
      AND t.user_id = (SELECT auth.uid())
  );
$$;

-- The current user reads the wishlist: it is theirs or public, or it holds a
-- wish they booked.
CREATE OR REPLACE FUNCTION public.can_read_wishlist(p_wishlist_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.wishlists wl
    WHERE wl.id = p_wishlist_id
      AND (
        wl.id_owner = (SELECT auth.uid())
        OR wl.visibility = 'public'
        OR EXISTS (
          SELECT 1
          FROM public.wishs w
          JOIN public.wish_taken_by_user t ON t.wish_id = w.id
          WHERE w.wishlist_id = wl.id
            AND t.user_id = (SELECT auth.uid())
        )
      )
  );
$$;

-- The current user reads the profile: their own, one they share a friendship
-- with, pending or accepted, not rejected or blocked (the pair is looked up
-- through friendships_pair_key), the owner of a
-- public wishlist or of a wishlist holding a wish they booked, or a user who
-- booked a wish they can read.
CREATE OR REPLACE FUNCTION public.can_read_profile(p_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p_profile_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.friendships f
      WHERE least(f.requester_id, f.receiver_id) = least((SELECT auth.uid()), p_profile_id)
        AND greatest(f.requester_id, f.receiver_id) = greatest((SELECT auth.uid()), p_profile_id)
        AND f.status IN ('pending', 'accepted')
    )
    OR EXISTS (
      SELECT 1
      FROM public.wishlists wl
      WHERE wl.id_owner = p_profile_id
        AND (
          wl.visibility = 'public'
          OR EXISTS (
            SELECT 1
            FROM public.wishs w
            JOIN public.wish_taken_by_user t ON t.wish_id = w.id
            WHERE w.wishlist_id = wl.id
              AND t.user_id = (SELECT auth.uid())
          )
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.wish_taken_by_user t
      JOIN public.wishs w ON w.id = t.wish_id
      WHERE t.user_id = p_profile_id
        AND public.can_read_wish(w.id, w.wishlist_id)
    );
$$;

REVOKE ALL ON FUNCTION public.can_read_wish(bigint, bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_read_wishlist(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_read_profile(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_read_wish(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_wishlist(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_profile(uuid) TO authenticated;


-- 2. wishlists

DROP POLICY IF EXISTS "Enable select for authenticated users only" ON public.wishlists;
DROP POLICY IF EXISTS "Users can read their own and public wishlists" ON public.wishlists;
CREATE POLICY "Users can read their own and public wishlists"
  ON public.wishlists
  FOR SELECT
  TO authenticated
  USING (public.can_read_wishlist(id));

-- 3. wishs

DROP POLICY IF EXISTS "Enable read access for authenticated users only" ON public.wishs;
DROP POLICY IF EXISTS "Users can read wishes of the wishlists they can read" ON public.wishs;
CREATE POLICY "Users can read wishes of the wishlists they can read"
  ON public.wishs
  FOR SELECT
  TO authenticated
  USING (public.can_read_wish(id, wishlist_id));

-- 4. profiles

DROP POLICY IF EXISTS "Enable read for authenticated users only" ON public.profiles;
DROP POLICY IF EXISTS "Users can read the profiles related to them" ON public.profiles;
CREATE POLICY "Users can read the profiles related to them"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.can_read_profile(id));


-- 5. Permissive policies add up (OR): fail if any SELECT or ALL policy other
-- than the ones above remains on these tables, for instance one created by
-- hand on a project.
DO $$
DECLARE
  extra text;
BEGIN
  SELECT string_agg(format('%s: "%s" (%s)', tablename, policyname, cmd), ', ')
  INTO extra
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('wishlists', 'wishs', 'profiles')
    AND permissive = 'PERMISSIVE'
    AND cmd IN ('SELECT', 'ALL')
    AND policyname NOT IN (
      'Users can read their own and public wishlists',
      'Users can read wishes of the wishlists they can read',
      'Users can read the profiles related to them'
    );

  IF extra IS NOT NULL THEN
    RAISE EXCEPTION 'Unexpected read policies left: %', extra;
  END IF;
END $$;


-- 6. can_read_profile looks up the wishlists of a profile for every row it
-- checks.

CREATE INDEX IF NOT EXISTS wishlists_id_owner_idx ON public.wishlists (id_owner);


-- Verification: tests in supabase-tests/read_policies.sql.
--
-- SELECT tablename, policyname, cmd FROM pg_policies
--  WHERE schemaname = 'public' AND tablename IN ('wishlists', 'wishs', 'profiles')
--    AND cmd IN ('SELECT', 'ALL');
--   -> one SELECT policy per table
--
-- SELECT p.proname, p.prosecdef, p.provolatile, p.proconfig
--   FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
--    AND p.proname IN ('can_read_wish', 'can_read_wishlist', 'can_read_profile');
--   -> prosecdef true, provolatile 's', proconfig {search_path=""}
