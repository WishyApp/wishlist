-- Restrict INSERT and UPDATE policies on wishlists, wishs and
-- wish_taken_by_user to the rows the current user owns.
--
-- - wishlists: only the owner creates or updates a wishlist, and cannot hand
--   it over to another user.
-- - wishs: only the owner of the wishlist creates or updates its wishes, and
--   a wish can only be moved to another wishlist of the same owner.
-- - wish_taken_by_user: a user books a wish in their own name, never on one
--   of their own wishlists.

-- 1. wishlists

DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.wishlists;
DROP POLICY IF EXISTS "Users can create their own wishlists" ON public.wishlists;
CREATE POLICY "Users can create their own wishlists"
  ON public.wishlists
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = id_owner);

DROP POLICY IF EXISTS "Enable update for authenticated users only" ON public.wishlists;
DROP POLICY IF EXISTS "Users can update their own wishlists" ON public.wishlists;
CREATE POLICY "Users can update their own wishlists"
  ON public.wishlists
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = id_owner)
  WITH CHECK ((SELECT auth.uid()) = id_owner);


-- 2. wishs

DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.wishs;
DROP POLICY IF EXISTS "Users can add wishes to their own wishlists" ON public.wishs;
CREATE POLICY "Users can add wishes to their own wishlists"
  ON public.wishs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.wishlists wl
      WHERE wl.id = wishs.wishlist_id
        AND wl.id_owner = (SELECT auth.uid())
    )
  );

-- USING checks the wishlist the wish is in, WITH CHECK the wishlist it ends
-- up in: both must belong to the current user.
DROP POLICY IF EXISTS "Enable update for authenticated users only" ON public.wishs;
DROP POLICY IF EXISTS "Users can update wishes of their own wishlists" ON public.wishs;
CREATE POLICY "Users can update wishes of their own wishlists"
  ON public.wishs
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.wishlists wl
      WHERE wl.id = wishs.wishlist_id
        AND wl.id_owner = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.wishlists wl
      WHERE wl.id = wishs.wishlist_id
        AND wl.id_owner = (SELECT auth.uid())
    )
  );


-- 3. wish_taken_by_user

DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.wish_taken_by_user;
DROP POLICY IF EXISTS "Users can book wishes of other users" ON public.wish_taken_by_user;
CREATE POLICY "Users can book wishes of other users"
  ON public.wish_taken_by_user
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.wishs w
      JOIN public.wishlists wl ON wl.id = w.wishlist_id
      WHERE w.id = wish_taken_by_user.wish_id
        AND wl.id_owner = (SELECT auth.uid())
    )
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
    AND NOT EXISTS (
      SELECT 1
      FROM public.wishs w
      JOIN public.wishlists wl ON wl.id = w.wishlist_id
      WHERE w.id = wish_taken_by_user.wish_id
        AND wl.id_owner = (SELECT auth.uid())
    )
  );


-- Verification:
-- SELECT tablename, policyname, cmd, qual, with_check FROM pg_policies
--  WHERE schemaname = 'public'
--    AND tablename IN ('wishlists', 'wishs', 'wish_taken_by_user')
--    AND cmd IN ('INSERT', 'UPDATE')
--  ORDER BY 1, 3;
--   -> 6 rows, none with qual or with_check = 'true'
