-- Prevent over-booking of a wish (F013).
--
-- Rule: the sum of the bookings (wish_taken_by_user.quantity) of a wish never
-- exceeds the quantity of the wish, and a booking is at least 1.
--
-- can_book_wish only checks one row against the wish quantity, so two friends
-- booking at the same time could both pass it and book more than wished. The
-- sum is checked by an AFTER INSERT/UPDATE trigger that first locks the wish
-- row: concurrent bookings of the same wish are serialized, and the second one
-- sees the committed booking of the first (each statement of a plpgsql
-- function takes a fresh snapshot, in READ COMMITTED) and fails.
-- The lock is FOR NO KEY UPDATE, not FOR UPDATE: the foreign key check of an
-- insert has already taken FOR KEY SHARE on the wish row, which FOR UPDATE
-- conflicts with. Two concurrent bookings would each hold KEY SHARE and, for
-- FOR UPDATE, wait for the other one to release it: a deadlock (40P01) even
-- when the quantity allows both. FOR NO KEY UPDATE does not conflict with KEY
-- SHARE, only with itself.
-- A trigger keeps the client unchanged (plain insert/update on the table) and
-- covers every write path. It is AFTER so that the RLS policies run first: a
-- user who may not book the wish neither locks it nor learns its bookings.
--
-- The trigger is SECURITY DEFINER because it locks the wish (UPDATE is
-- restricted to its owner by RLS) and must count the bookings of all users.
-- Error: check_violation (23514) with the message 'wish_overbooked', mapped by
-- the client.
--
-- The owner cannot lower wishs.quantity below the already booked total
-- (nobody would be notified of the bookings left above the quantity): a second
-- AFTER UPDATE OF quantity trigger on wishs, fired only when the quantity goes
-- down, refuses it with the message 'wish_quantity_below_booked'. The error
-- gives no booking count or name: the owner may not be allowed to read the
-- bookings. Wishes already over-booked before this migration are left as they
-- are, and lowering or cancelling a booking is always allowed so that bookers
-- can get back under the quantity.
-- restore_completed_wish puts a wish back with the quantity received, which
-- can be lower than what is still booked: it now restores
-- GREATEST(received quantity, booked total), so that it never fails on the
-- trigger above and never leaves the wish over-booked.
-- Concurrency with the booking trigger: the UPDATE on wishs holds a FOR NO KEY
-- UPDATE row lock on the wish until commit, and the booking trigger takes the
-- same lock before summing. If the owner goes first, the booking trigger waits,
-- then reads the new quantity and refuses an over-booking. If a booking goes
-- first, the owner's UPDATE waits for its commit and the wishs trigger then
-- sums the bookings with a fresh snapshot, including the new one. No deadlock:
-- the wishs trigger takes no lock besides the one its UPDATE already holds.

-- 1. A booking is at least 1. A booking of 0 or less has no meaning (the
-- client deletes the row instead): remove such rows left by old versions so
-- that the constraint can be validated.

DELETE FROM public.wish_taken_by_user WHERE quantity < 1;

ALTER TABLE public.wish_taken_by_user
  DROP CONSTRAINT IF EXISTS wish_taken_by_user_quantity_positive;
ALTER TABLE public.wish_taken_by_user
  ADD CONSTRAINT wish_taken_by_user_quantity_positive CHECK (quantity >= 1);


-- 2. Total of the bookings of a wish within its quantity.

CREATE OR REPLACE FUNCTION public.check_wish_not_overbooked()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_wish_quantity bigint;
  v_booked bigint;
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

  IF v_booked > v_wish_quantity THEN
    RAISE EXCEPTION 'wish_overbooked'
      USING ERRCODE = 'check_violation',
            DETAIL = format('wish %s: %s booked for a quantity of %s',
                            NEW.wish_id, v_booked, v_wish_quantity);
  END IF;

  RETURN NULL;
END $$;

REVOKE ALL ON FUNCTION public.check_wish_not_overbooked() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS check_wish_not_overbooked ON public.wish_taken_by_user;
CREATE TRIGGER check_wish_not_overbooked
  AFTER INSERT OR UPDATE OF quantity, wish_id ON public.wish_taken_by_user
  FOR EACH ROW
  EXECUTE FUNCTION public.check_wish_not_overbooked();


-- 3. The owner cannot lower the quantity of a wish below its booked total.

CREATE OR REPLACE FUNCTION public.check_wish_quantity_not_below_booked()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF (
    SELECT COALESCE(SUM(t.quantity), 0)
    FROM public.wish_taken_by_user t
    WHERE t.wish_id = NEW.id
  ) > NEW.quantity THEN
    RAISE EXCEPTION 'wish_quantity_below_booked'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NULL;
END $$;

REVOKE ALL ON FUNCTION public.check_wish_quantity_not_below_booked() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS check_wish_quantity_not_below_booked ON public.wishs;
CREATE TRIGGER check_wish_quantity_not_below_booked
  AFTER UPDATE OF quantity ON public.wishs
  FOR EACH ROW
  WHEN (NEW.quantity < OLD.quantity)
  EXECUTE FUNCTION public.check_wish_quantity_not_below_booked();


-- 4. restore_completed_wish keeps at least the booked total. Same definition as
-- 20260725000001 (signature, SECURITY DEFINER, search_path, checks, errors);
-- only the quantity computation changes. The wish row is locked FOR NO KEY
-- UPDATE before the bookings are summed, like the booking trigger does, so
-- that no booking can slip in between the sum and the UPDATE.

CREATE OR REPLACE FUNCTION public.restore_completed_wish(
  p_wish_id bigint,
  p_target_wishlist_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  completed_quantity bigint;
  booked_quantity bigint;
BEGIN
  SELECT quantity
  INTO completed_quantity
  FROM public.user_completed_wishs
  WHERE user_id = auth.uid()
    AND wish_id = p_wish_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Completed wish not found for current user';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.wishlists
    WHERE id = p_target_wishlist_id
      AND id_owner = auth.uid()
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Target wishlist not found or not owned by current user';
  END IF;

  PERFORM 1 FROM public.wishs WHERE id = p_wish_id FOR NO KEY UPDATE;

  SELECT COALESCE(SUM(quantity), 0)
  INTO booked_quantity
  FROM public.wish_taken_by_user
  WHERE wish_id = p_wish_id;

  UPDATE public.wishs AS wish
  SET wishlist_id = p_target_wishlist_id,
      quantity = GREATEST(completed_quantity, booked_quantity),
      updated_by = auth.uid()
  FROM public.wishlists AS source_wishlist
  WHERE wish.id = p_wish_id
    AND source_wishlist.id = wish.wishlist_id
    AND source_wishlist.id_owner = auth.uid()
    AND source_wishlist.deleted_at IS NOT NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wish is not in an archived wishlist owned by current user';
  END IF;

  DELETE FROM public.user_completed_wishs
  WHERE user_id = auth.uid()
    AND wish_id = p_wish_id;
END;
$$;


-- Verification: tests in supabase-tests/write_policies.sql (sequential cases;
-- the concurrent case relies on the row lock above).
-- Constraint and trigger present:
--   SELECT conname FROM pg_constraint WHERE conname = 'wish_taken_by_user_quantity_positive';
--   SELECT tgname FROM pg_trigger WHERE tgname IN ('check_wish_not_overbooked', 'check_wish_quantity_not_below_booked');
-- Wishes already over-booked before this migration (left as they are):
--   SELECT t.wish_id, sum(t.quantity) AS booked, w.quantity
--   FROM public.wish_taken_by_user t JOIN public.wishs w ON w.id = t.wish_id
--   GROUP BY t.wish_id, w.quantity HAVING sum(t.quantity) > w.quantity;
