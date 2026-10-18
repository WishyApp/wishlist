-- A booking only uses what the owner has not received yet.
--
-- When the owner marks a wish as received, the wish keeps its quantity and the
-- received quantity is stored in user_completed_wishs (one row per owner and
-- wish). The app displays quantity - booked - received as the quantity still
-- pending, but check_wish_not_overbooked (20261018110000) only compared the
-- bookings with the quantity: a fully received wish of an active wishlist stayed
-- bookable.
--
-- New rule, same formula as the app: when a booking is created or increased
-- (INSERT, UPDATE raising the quantity or moving the booking to another wish),
--   sum(bookings of the wish) + received quantity <= wishs.quantity
-- where the received quantity is the one recorded by the owner of the wishlist
-- holding the wish (user_completed_wishs.user_id = wishlists.id_owner).
-- otherwise check_violation with the message 'wish_overbooked'. Lowering or
-- cancelling a booking is still always allowed (early return unchanged).
--
-- Marking a wish as received is deliberately not checked: a friend may have
-- booked the wish before the owner receives it, and the total can then exceed
-- the quantity. Such a wish accepts no new booking, and its bookers can still
-- lower or cancel theirs. No trigger on user_completed_wishs. The quantity
-- floor of the owner (wish_quantity_below_booked) and restore_completed_wish
-- are unchanged: they only look at the bookings.
--
-- Same definition as 20261018110000 otherwise (FOR NO KEY UPDATE lock on the
-- wish, SECURITY DEFINER, search_path = '', same error and detail shape); the
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

  IF v_booked + v_received > v_wish_quantity THEN
    RAISE EXCEPTION 'wish_overbooked'
      USING ERRCODE = 'check_violation',
            DETAIL = format('wish %s: %s booked and %s received for a quantity of %s',
                            NEW.wish_id, v_booked, v_received, v_wish_quantity);
  END IF;

  RETURN NULL;
END $$;


-- Verification: tests in supabase-tests/write_policies.sql.
-- Function ACL unchanged (no EXECUTE for PUBLIC, anon, authenticated):
--   SELECT proacl FROM pg_proc WHERE proname = 'check_wish_not_overbooked';
-- Wishes that cannot be booked any more because of received quantities:
--   SELECT w.id, w.quantity, sum(c.quantity) AS received
--   FROM public.wishs w JOIN public.user_completed_wishs c ON c.wish_id = w.id
--   GROUP BY w.id, w.quantity;
