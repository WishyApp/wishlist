-- Restrict INSERT and UPDATE policies on wishlists, wishs and
-- wish_taken_by_user to the rows the current user owns.
--
-- - wishlists: only the owner creates or updates a wishlist, and cannot hand
--   it over to another user.
-- - wishs: only the owner of the wishlist creates or updates its wishes, and
--   a wish can only be moved to another wishlist of the same owner.
-- - wish_taken_by_user: a user books, in their own name, a wish of a public
--   and open wishlist that is not theirs, for a quantity between 1 and the
--   quantity of the wish.
-- - updated_by is the current user on every insert and update.

-- 1. Shared rules, defined once for all policies. SECURITY INVOKER: they read
-- wishlists and wishs with the caller's rights.

CREATE OR REPLACE FUNCTION public.is_wishlist_owner(p_wishlist_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.wishlists wl
    WHERE wl.id = p_wishlist_id
      AND wl.id_owner = (SELECT auth.uid())
  );
$$;

CREATE OR REPLACE FUNCTION public.can_book_wish(p_wish_id bigint, p_quantity bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.wishs w
    JOIN public.wishlists wl ON wl.id = w.wishlist_id
    WHERE w.id = p_wish_id
      AND wl.id_owner <> (SELECT auth.uid())
      AND wl.visibility = 'public'
      AND NOT wl.is_closed
      AND p_quantity BETWEEN 1 AND w.quantity
  );
$$;

REVOKE ALL ON FUNCTION public.is_wishlist_owner(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_book_wish(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_wishlist_owner(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_book_wish(bigint, bigint) TO authenticated;


-- 2. wishlists

DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.wishlists;
DROP POLICY IF EXISTS "Users can create their own wishlists" ON public.wishlists;
CREATE POLICY "Users can create their own wishlists"
  ON public.wishlists
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = id_owner
    AND (SELECT auth.uid()) = updated_by
  );

DROP POLICY IF EXISTS "Enable update for authenticated users only" ON public.wishlists;
DROP POLICY IF EXISTS "Users can update their own wishlists" ON public.wishlists;
CREATE POLICY "Users can update their own wishlists"
  ON public.wishlists
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = id_owner)
  WITH CHECK (
    (SELECT auth.uid()) = id_owner
    AND (SELECT auth.uid()) = updated_by
  );


-- 3. wishs

DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.wishs;
DROP POLICY IF EXISTS "Users can add wishes to their own wishlists" ON public.wishs;
CREATE POLICY "Users can add wishes to their own wishlists"
  ON public.wishs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_wishlist_owner(wishlist_id)
    AND (SELECT auth.uid()) = updated_by
  );

-- USING checks the wishlist the wish is in, WITH CHECK the wishlist it ends
-- up in: both must belong to the current user.
DROP POLICY IF EXISTS "Enable update for authenticated users only" ON public.wishs;
DROP POLICY IF EXISTS "Users can update wishes of their own wishlists" ON public.wishs;
CREATE POLICY "Users can update wishes of their own wishlists"
  ON public.wishs
  FOR UPDATE
  TO authenticated
  USING (public.is_wishlist_owner(wishlist_id))
  WITH CHECK (
    public.is_wishlist_owner(wishlist_id)
    AND (SELECT auth.uid()) = updated_by
  );


-- 4. wish_taken_by_user

DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.wish_taken_by_user;
DROP POLICY IF EXISTS "Users can book wishes of other users" ON public.wish_taken_by_user;
CREATE POLICY "Users can book wishes of other users"
  ON public.wish_taken_by_user
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND public.can_book_wish(wish_id, quantity)
  );

DROP POLICY IF EXISTS "Enable update for authenticated users based on user_id" ON public.wish_taken_by_user;
DROP POLICY IF EXISTS "Users can update their own bookings" ON public.wish_taken_by_user;
CREATE POLICY "Users can update their own bookings"
  ON public.wish_taken_by_user
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND public.can_book_wish(wish_id, quantity)
  );


-- 5. Permissive policies add up (OR): fail if any INSERT, UPDATE or ALL
-- policy other than the ones above remains on these tables, for instance one
-- created by hand on a project.

DO $$
DECLARE
  extra text;
BEGIN
  SELECT string_agg(format('%s: "%s" (%s)', tablename, policyname, cmd), ', ')
  INTO extra
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('wishlists', 'wishs', 'wish_taken_by_user')
    AND permissive = 'PERMISSIVE'
    AND cmd IN ('INSERT', 'UPDATE', 'ALL')
    AND policyname NOT IN (
      'Users can create their own wishlists',
      'Users can update their own wishlists',
      'Users can add wishes to their own wishlists',
      'Users can update wishes of their own wishlists',
      'Users can book wishes of other users',
      'Users can update their own bookings'
    );

  IF extra IS NOT NULL THEN
    RAISE EXCEPTION 'Unexpected write policies left: %', extra;
  END IF;
END $$;


-- Verification: tests in supabase-tests/write_policies.sql.
