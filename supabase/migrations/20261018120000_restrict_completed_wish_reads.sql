-- Restrict SELECT on user_completed_wishs: a user reads their own completed
-- wishes, and the completed wishes they can read the wish of.
--
-- The app reads the completed wishes of a user, filtered by user_id: the
-- current user's (completed wishes screen), a friend's (friend details
-- screen), and those of the owner of the wishlist being viewed (the wishlist
-- screen subtracts the completed quantity from its wishes). Each row is
-- embedded with its wish (wishs!inner), its wishlist and the owner of that
-- wishlist, so a row is useful to a reader only if they can read that wish.
-- The rule follows:
--
-- - the row is the current user's (user_id = auth.uid()): always readable,
--   whatever happened to the wish since, and without calling a function, so
--   that INSERT ... RETURNING (what insert().select() sends) checks the
--   policy on the new row without reading anything back;
-- - otherwise, the current user reads the wish the row points to
--   (can_read_wish): its wishlist is theirs or public, archived or not (the
--   app shows "Wishlist supprimée" for an archived one), or they booked the
--   wish. A private wishlist keeps its completed wishes out of reach of
--   other users.
--
-- The wish is read through its current wishlist, not through from_wishlist_id:
-- a wish moved to a private wishlist stops being readable, even though the row
-- still holds the wishlist it was completed from. wish_id is a foreign key
-- with ON DELETE CASCADE, so the wish exists as long as the row does: there is
-- no fallback, a wish that cannot be found is not readable. (A fallback on
-- from_wishlist_id would be unreachable from the policy, and the function,
-- callable through RPC with arbitrary arguments, would then tell whether a
-- private wish exists.)
--
-- Writes are unchanged (INSERT, UPDATE and DELETE are limited to the owner of
-- the wish or the row).
--
-- The lookup lives in a SECURITY DEFINER function, so that the policies of
-- user_completed_wishs and wishs never evaluate each other.
--
-- Known limit (Realtime): the table stays in the supabase_realtime
-- publication. INSERT/UPDATE events are filtered through this policy, DELETE
-- events are not filtered by RLS and carry the primary key (user_id, wish_id)
-- of the deleted row to every subscriber of the table.

-- 1. Shared rule. SECURITY DEFINER with a pinned search_path: it reads wishs
-- without going through its policy, then relies on the helpers of
-- 20261012100000_restrict_private_wishlist_reads. It only answers about the
-- current user (auth.uid()).
CREATE OR REPLACE FUNCTION public.can_read_completed_wish(
  p_wish_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    (
      SELECT public.can_read_wish(w.id, w.wishlist_id)
      FROM public.wishs w
      WHERE w.id = p_wish_id
    ),
    false
  );
$$;

REVOKE ALL ON FUNCTION public.can_read_completed_wish(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_read_completed_wish(bigint) TO authenticated;


-- 2. user_completed_wishs

DROP POLICY IF EXISTS "Authenticated users can read completed wishes" ON public.user_completed_wishs;
DROP POLICY IF EXISTS "Users can read their own and readable completed wishes" ON public.user_completed_wishs;
CREATE POLICY "Users can read their own and readable completed wishes"
  ON public.user_completed_wishs
  FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR public.can_read_completed_wish(wish_id)
  );


-- 3. Permissive policies add up (OR): fail if any SELECT or ALL policy other
-- than the one above remains on the table, for instance one created by hand
-- on a project.
DO $$
DECLARE
  extra text;
BEGIN
  SELECT string_agg(format('"%s" (%s)', policyname, cmd), ', ')
  INTO extra
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'user_completed_wishs'
    AND permissive = 'PERMISSIVE'
    AND cmd IN ('SELECT', 'ALL')
    AND policyname <> 'Users can read their own and readable completed wishes';

  IF extra IS NOT NULL THEN
    RAISE EXCEPTION 'Unexpected read policies left on user_completed_wishs: %', extra;
  END IF;
END $$;


-- Verification: tests in supabase-tests/completed_wish_read_policies.sql.
--
-- SELECT policyname, cmd FROM pg_policies
--  WHERE schemaname = 'public' AND tablename = 'user_completed_wishs'
--    AND cmd IN ('SELECT', 'ALL');
--   -> one SELECT policy
--
-- SELECT p.proname, p.prosecdef, p.provolatile, p.proconfig
--   FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
--    AND p.proname = 'can_read_completed_wish';
--   -> prosecdef true, provolatile 's', proconfig {search_path=""}
