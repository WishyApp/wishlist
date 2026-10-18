-- Restrict SELECT on wish_taken_by_user: the owner of a wishlist reads who
-- booked their wishes only when the wishlist allows it.
--
-- - A user reads their own bookings (a booker always sees what they booked,
--   including right after the insert: INSERT ... RETURNING checks this policy).
-- - The other bookings of a wish are read by the users who can read the wish
--   through a public wishlist that is not theirs (the app computes the
--   available quantity from them).
-- - The owner of the wishlist reads the bookings of its wishes only if
--   can_owner_see_taken_wish is true, whether the wishlist is public or not.
-- - Nobody else reads a booking: the bookers of a wish of a private wishlist
--   only see their own.
--
-- What the owner screens use when can_owner_see_taken_wish is false: nothing
-- but the wishes themselves. The app already hides the booked tab, the counts
-- and the "booked" state in that case (isWishsBookedHidden), and every
-- aggregate it displays to the owner comes from the rows of this table, which
-- the owner now reads as empty. The edit form no longer stops the owner from
-- setting a quantity below the booked one in that case: it only knows the
-- bookings it reads. Deleting a wish, a wishlist or an account cascades
-- through the foreign keys, which do not go through RLS.
--
-- can_owner_see_taken_wish is a setting of the owner: turning it on, or
-- moving a wish to a wishlist where it is on, shows the bookings already made.
--
-- The lookup lives in a SECURITY DEFINER function that reads wishs and
-- wishlists only, so that the policy of wish_taken_by_user never evaluates the
-- policies of the other tables, which call back into wish_taken_by_user
-- (has_booked_wish_in, can_read_wish).
--
-- can_read_profile is redefined: the profile of a booker was readable by
-- whoever could read the wish, owner included. It now follows the same rule as
-- the bookings, otherwise a plain SELECT on profiles would still tell the owner
-- that a user booked one of their wishes.
--
-- Realtime: the table stays in the supabase_realtime publication.
-- INSERT/UPDATE events are filtered through this policy, a subscriber only
-- receives the rows it can read. DELETE events are not filtered by RLS and
-- carry the primary key (user_id, wish_id) of the deleted row, whatever the
-- replica identity: see the note at the end.

-- 1. Shared rule. SECURITY DEFINER with a pinned search_path: reads wishs and
-- wishlists without going through their policies. It only answers about the
-- current user (auth.uid()). The booker reading their own row is handled by
-- the policy, which does not need a lookup.

-- The current user reads the bookings of other users on the wish: the wishlist
-- is public and not theirs, or it is theirs and allows seeing the bookings.
CREATE OR REPLACE FUNCTION public.can_read_wish_bookings(p_wish_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.wishs w
    JOIN public.wishlists wl ON wl.id = w.wishlist_id
    WHERE w.id = p_wish_id
      AND CASE
        WHEN wl.id_owner = (SELECT auth.uid()) THEN wl.can_owner_see_taken_wish
        ELSE wl.visibility = 'public'
      END
  );
$$;

REVOKE ALL ON FUNCTION public.can_read_wish_bookings(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_read_wish_bookings(bigint) TO authenticated;


-- 2. wish_taken_by_user

DROP POLICY IF EXISTS "Enable read access for authenticated users only" ON public.wish_taken_by_user;
DROP POLICY IF EXISTS "Users can read their own bookings and the ones they may see" ON public.wish_taken_by_user;
CREATE POLICY "Users can read their own bookings and the ones they may see"
  ON public.wish_taken_by_user
  FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR public.can_read_wish_bookings(wish_id)
  );


-- 3. profiles: same rule as before (see 20261012100000), except that a booker
-- is readable only through a booking the current user may read. The previous
-- can_read_wish test is dropped: can_read_wish_bookings implies it (the
-- wishlist is the current user's or public).

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
        AND public.can_read_wishlist(wl.id)
    )
    OR EXISTS (
      SELECT 1
      FROM public.wish_taken_by_user t
      WHERE t.user_id = p_profile_id
        AND public.can_read_wish_bookings(t.wish_id)
    );
$$;


-- 4. Permissive policies add up (OR): fail if any SELECT or ALL policy other
-- than the one above remains on the table, for instance one created by hand
-- on a project.
DO $$
DECLARE
  extra text;
BEGIN
  SELECT string_agg(format('%s: "%s" (%s)', tablename, policyname, cmd), ', ')
  INTO extra
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'wish_taken_by_user'
    AND permissive = 'PERMISSIVE'
    AND cmd IN ('SELECT', 'ALL')
    AND policyname <> 'Users can read their own bookings and the ones they may see';

  IF extra IS NOT NULL THEN
    RAISE EXCEPTION 'Unexpected read policies left: %', extra;
  END IF;
END $$;


-- Known limit (Realtime): DELETE events of postgres_changes are not filtered
-- by RLS, and with RLS on the old record is reduced to the primary key, which
-- here is (user_id, wish_id), sent to every subscriber of the table.
-- Changing the replica identity does not change that. The
-- wishlist screen subscribes to the table without a filter, the other screens
-- with an eq filter, which Realtime does not apply to DELETE either. A
-- full fix is to publish the changes through a private Realtime channel
-- (realtime.broadcast_changes from a trigger, authorised by RLS), left out
-- of this migration.


-- Verification: tests in supabase-tests/booking_read_policies.sql.
--
-- SELECT policyname, cmd FROM pg_policies
--  WHERE schemaname = 'public' AND tablename = 'wish_taken_by_user'
--    AND cmd IN ('SELECT', 'ALL');
--   -> one SELECT policy
--
-- SELECT p.proname, p.prosecdef, p.provolatile, p.proconfig
--   FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
--    AND p.proname IN ('can_read_wish_bookings', 'can_read_profile');
--   -> prosecdef true, provolatile 's', proconfig {search_path=""}
