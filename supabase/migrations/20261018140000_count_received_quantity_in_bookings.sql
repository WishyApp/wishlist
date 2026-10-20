-- A received quantity consumes the bookings first.
--
-- When the owner marks a wish as received, the wish keeps its quantity and the
-- received quantity is stored in user_completed_wishs (one row per owner and
-- wish). check_wish_not_overbooked (20261018110000) only compared the bookings
-- with the quantity: a fully received wish of an active wishlist stayed
-- bookable.
--
-- Rule: the pending quantity of a wish is
--   wishs.quantity - GREATEST(sum(bookings of the wish), received quantity)
-- and a booking created or increased (INSERT, UPDATE raising the quantity or
-- moving the booking to another wish) may not exceed it, i.e. with n the added
-- quantity and the totals taken before the change:
--   GREATEST(booked, received) + n <= wishs.quantity
-- The received quantity is the one recorded by the owner of the wishlist
-- holding the wish (user_completed_wishs.user_id = wishlists.id_owner).
-- Otherwise check_violation with the message 'wish_overbooked'. Lowering or
-- cancelling a booking is still always allowed (early return unchanged).
-- Examples (quantity 3): 1 booked and 1 received leaves 2 to book; 1 received
-- and nothing booked leaves 2; a fully received wish leaves 0.
--
-- Rationale: the usual flow is a friend booking a wish, giving it, then the
-- owner marking it received: the booking stays and the received quantity is
-- the same item, so both must not add up. A gift received from outside the app
-- is handled by someone booking it on the owner's behalf, or by the owner
-- lowering the quantity of the wish. The app uses the same rule: pending
-- quantity = quantity - GREATEST(booked, received).
--
-- Marking a wish as received is deliberately not checked, whatever the
-- bookings. No trigger on user_completed_wishs. The quantity floor of the
-- owner (wish_quantity_below_booked) and restore_completed_wish are unchanged:
-- they only look at the bookings.
--
-- Same definition as 20261018110000 otherwise (FOR NO KEY UPDATE lock on the
-- wish, SECURITY DEFINER, search_path = '', same error; the detail now also
-- gives the added and received quantities); the
-- function owner reads user_completed_wishs, which a booker could not filter by
-- RLS. CREATE OR REPLACE keeps the existing ACL (revoked from PUBLIC, anon and
-- authenticated) and the trigger.

CREATE OR REPLACE FUNCTION public.check_wish_not_overbooked()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_wish_quantity bigint;
  v_booked bigint;
  v_received bigint;
  v_added bigint;
BEGIN
  -- A booking lowered (or left as is) on the same wish cannot over-book it.
  IF TG_OP = 'UPDATE'
     AND NEW.wish_id = OLD.wish_id
     AND NEW.quantity <= OLD.quantity THEN
    RETURN NULL;
  END IF;

  -- Serializes the bookings of this wish until the end of the transaction.
  SELECT w.quantity INTO v_wish_quantity
  FROM public.wishs w
  WHERE w.id = NEW.wish_id
  FOR NO KEY UPDATE;

  SELECT COALESCE(SUM(t.quantity), 0) INTO v_booked
  FROM public.wish_taken_by_user t
  WHERE t.wish_id = NEW.wish_id;

  -- Only the owner's completion counts (the app reads the same row). Rows of
  -- other users, possible before the insert policy of 20260516000000 and still
  -- updatable by their author, must not let them block the bookings.
  SELECT COALESCE(SUM(c.quantity), 0) INTO v_received
  FROM public.user_completed_wishs c
  JOIN public.wishs w ON w.id = c.wish_id
  JOIN public.wishlists wl ON wl.id = w.wishlist_id
  WHERE c.wish_id = NEW.wish_id
    AND c.user_id = wl.id_owner;

  -- Quantity added by this statement to the bookings of the wish (v_booked
  -- already contains it): the whole booking, or the increase on the same wish.
  v_added := NEW.quantity
             - CASE WHEN TG_OP = 'UPDATE' AND NEW.wish_id = OLD.wish_id
                    THEN OLD.quantity ELSE 0 END;

  -- GREATEST(booked before, received) + added = GREATEST(v_booked, received + added)
  IF GREATEST(v_booked, v_received + v_added) > v_wish_quantity THEN
    RAISE EXCEPTION 'wish_overbooked'
      USING ERRCODE = 'check_violation',
            DETAIL = format('wish %s: %s booked (including %s added), %s received, quantity of %s',
                            NEW.wish_id, v_booked, v_added, v_received, v_wish_quantity);
  END IF;

  RETURN NULL;
END $$;


-- Verification: tests in supabase-tests/write_policies.sql.
-- Function ACL unchanged (no EXECUTE for PUBLIC, anon, authenticated):
--   SELECT proacl FROM pg_proc WHERE proname = 'check_wish_not_overbooked';
-- Wishes that cannot be booked any more because of received quantities (received >= quantity):
--   SELECT w.id, w.quantity, sum(c.quantity) AS received
--   FROM public.wishs w JOIN public.user_completed_wishs c ON c.wish_id = w.id
--   GROUP BY w.id, w.quantity;
