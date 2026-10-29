-- Write policies of wishlists, wishs and wish_taken_by_user
-- (20261011000000_restrict_write_policies_to_owner).
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

-- Functions created by postgres have no EXECUTE for PUBLIC by default
-- (20261012110000_restrict_anon_privileges): the helpers below are called
-- after switching role. Rolled back with the rest.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

-- Expectations, run with the current role.
CREATE FUNCTION pg_temp.expect_denied(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: allowed, expected a denial', label;
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'ok   % (denied)', label;
END $$;

CREATE FUNCTION pg_temp.expect_rows(label text, statement text, expected int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  n int;
BEGIN
  EXECUTE statement;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> expected THEN
    RAISE EXCEPTION 'FAIL %: % row(s), expected %', label, n, expected;
  END IF;
  RAISE NOTICE 'ok   % (% row(s))', label, n;
END $$;

-- Fixtures: A (acting user), B and C, each with wishlists and wishes.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-a000-00000000000a'),
  ('00000000-0000-4000-a000-00000000000b'),
  ('00000000-0000-4000-a000-00000000000c');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-a000-00000000000a', 'test_a'),
  ('00000000-0000-4000-a000-00000000000b', 'test_b'),
  ('00000000-0000-4000-a000-00000000000c', 'test_c');
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility, is_closed) VALUES
  (900001, 'A public',  '00000000-0000-4000-a000-00000000000a', '#FFFFFF', '00000000-0000-4000-a000-00000000000a', 'public',  false),
  (900002, 'A other',   '00000000-0000-4000-a000-00000000000a', '#FFFFFF', '00000000-0000-4000-a000-00000000000a', 'public',  false),
  (900003, 'B public',  '00000000-0000-4000-a000-00000000000b', '#FFFFFF', '00000000-0000-4000-a000-00000000000b', 'public',  false),
  (900004, 'B private', '00000000-0000-4000-a000-00000000000b', '#FFFFFF', '00000000-0000-4000-a000-00000000000b', 'private', false),
  (900005, 'B closed',  '00000000-0000-4000-a000-00000000000b', '#FFFFFF', '00000000-0000-4000-a000-00000000000b', 'public',  true),
  (900007, 'C public', '00000000-0000-4000-a000-00000000000c', '#FFFFFF', '00000000-0000-4000-a000-00000000000c', 'public', false);
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, quantity) VALUES
  (910001, 'A wish',         '', 900001, '00000000-0000-4000-a000-00000000000a', 1),
  (910003, 'B wish',         '', 900003, '00000000-0000-4000-a000-00000000000b', 2),
  (910004, 'B private wish', '', 900004, '00000000-0000-4000-a000-00000000000b', 1),
  (910005, 'B closed wish',  '', 900005, '00000000-0000-4000-a000-00000000000b', 1),
  (910007, 'C wish',         '', 900007, '00000000-0000-4000-a000-00000000000c', 1);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000a', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000a", "role": "authenticated"}', true);

-- wishlists
SELECT pg_temp.expect_denied('wishlist created for another user',
  $q$INSERT INTO public.wishlists (name, id_owner, color, updated_by) VALUES ('x', '00000000-0000-4000-a000-00000000000b', '#FFFFFF', '00000000-0000-4000-a000-00000000000a')$q$);
SELECT pg_temp.expect_denied('wishlist created with another updated_by',
  $q$INSERT INTO public.wishlists (name, id_owner, color, updated_by) VALUES ('x', '00000000-0000-4000-a000-00000000000a', '#FFFFFF', '00000000-0000-4000-a000-00000000000b')$q$);
SELECT pg_temp.expect_rows('wishlist of another user updated',
  $q$UPDATE public.wishlists SET name = 'x' WHERE id = 900003$q$, 0);
SELECT pg_temp.expect_denied('own wishlist handed over',
  $q$UPDATE public.wishlists SET id_owner = '00000000-0000-4000-a000-00000000000b' WHERE id = 900001$q$);
SELECT pg_temp.expect_denied('own wishlist updated with another updated_by',
  $q$UPDATE public.wishlists SET updated_by = '00000000-0000-4000-a000-00000000000b' WHERE id = 900001$q$);
SELECT pg_temp.expect_rows('own wishlist created',
  $q$INSERT INTO public.wishlists (id, name, id_owner, color, updated_by) VALUES (900006, 'mine', '00000000-0000-4000-a000-00000000000a', '#FFFFFF', '00000000-0000-4000-a000-00000000000a')$q$, 1);
SELECT pg_temp.expect_rows('own wishlist updated',
  $q$UPDATE public.wishlists SET name = 'renamed' WHERE id = 900001$q$, 1);

-- wishs
SELECT pg_temp.expect_denied('wish added to a wishlist of another user',
  $q$INSERT INTO public.wishs (name, description, wishlist_id, updated_by) VALUES ('x', '', 900003, '00000000-0000-4000-a000-00000000000a')$q$);
SELECT pg_temp.expect_denied('wish added with another updated_by',
  $q$INSERT INTO public.wishs (name, description, wishlist_id, updated_by) VALUES ('x', '', 900001, '00000000-0000-4000-a000-00000000000b')$q$);
SELECT pg_temp.expect_rows('wish of another user updated',
  $q$UPDATE public.wishs SET name = 'x' WHERE id = 910003$q$, 0);
SELECT pg_temp.expect_denied('own wish moved to a wishlist of another user',
  $q$UPDATE public.wishs SET wishlist_id = 900003 WHERE id = 910001$q$);
SELECT pg_temp.expect_rows('wish added to own wishlist',
  $q$INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by) VALUES (910002, 'new', '', 900001, '00000000-0000-4000-a000-00000000000a')$q$, 1);
SELECT pg_temp.expect_rows('own wish moved between own wishlists',
  $q$UPDATE public.wishs SET wishlist_id = 900002 WHERE id = 910002$q$, 1);

-- wish_taken_by_user
SELECT pg_temp.expect_denied('booking in the name of another user',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910003, '00000000-0000-4000-a000-00000000000b', 1)$q$);
SELECT pg_temp.expect_denied('booking of an own wish',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910001, '00000000-0000-4000-a000-00000000000a', 1)$q$);
SELECT pg_temp.expect_denied('booking of a wish of a private wishlist of another user',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910004, '00000000-0000-4000-a000-00000000000a', 1)$q$);
SELECT pg_temp.expect_denied('booking in a closed wishlist',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910005, '00000000-0000-4000-a000-00000000000a', 1)$q$);
SELECT pg_temp.expect_rows('booking of a public wish of a user without relation',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910007, '00000000-0000-4000-a000-00000000000a', 1)$q$, 1);
SELECT pg_temp.expect_denied('booking of quantity 0',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910003, '00000000-0000-4000-a000-00000000000a', 0)$q$);
SELECT pg_temp.expect_denied('booking above the wish quantity',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910003, '00000000-0000-4000-a000-00000000000a', 3)$q$);
SELECT pg_temp.expect_rows('booking of a public wish of another user',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910003, '00000000-0000-4000-a000-00000000000a', 1)$q$, 1);
SELECT pg_temp.expect_rows('own booking quantity updated within the wish quantity',
  $q$UPDATE public.wish_taken_by_user SET quantity = 2 WHERE wish_id = 910003 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$, 1);
SELECT pg_temp.expect_denied('own booking quantity updated above the wish quantity',
  $q$UPDATE public.wish_taken_by_user SET quantity = 3 WHERE wish_id = 910003 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$);
SELECT pg_temp.expect_denied('own booking moved onto an own wish',
  $q$UPDATE public.wish_taken_by_user SET wish_id = 910001 WHERE wish_id = 910003 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$);

-- Over-booking (20261018110000_prevent_overbooking): wish 910003 has a quantity
-- of 2 and A already books 2 of it. B (owner) cannot book; C (fixtures) books as a third user.
RESET ROLE;
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, quantity) VALUES
  (910006, 'B wish x3', '', 900003, '00000000-0000-4000-a000-00000000000b', 3);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000c', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000c", "role": "authenticated"}', true);

CREATE FUNCTION pg_temp.expect_overbooked(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: allowed, expected wish_overbooked', label;
EXCEPTION WHEN check_violation THEN
  IF SQLERRM <> 'wish_overbooked' THEN RAISE; END IF;
  RAISE NOTICE 'ok   % (wish_overbooked)', label;
END $$;

SELECT pg_temp.expect_overbooked('second user booking a fully booked wish',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910003, '00000000-0000-4000-a000-00000000000c', 1)$q$);
SELECT pg_temp.expect_rows('booking up to the wish quantity (1 of 3)',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910006, '00000000-0000-4000-a000-00000000000c', 1)$q$, 1);
SELECT pg_temp.expect_rows('own booking updated within the remaining quantity (3 of 3)',
  $q$UPDATE public.wish_taken_by_user SET quantity = 3 WHERE wish_id = 910006 AND user_id = '00000000-0000-4000-a000-00000000000c'$q$, 1);

-- A books 1 more of 910006 while C holds 3 of 3.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000a', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000a", "role": "authenticated"}', true);
SELECT pg_temp.expect_overbooked('booking beyond the remaining quantity',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910006, '00000000-0000-4000-a000-00000000000a', 1)$q$);

-- Wish 910107 ends up over-booked (quantity 1, A books 2 and C books 1, as
-- before the quantity trigger existed): A can still lower their booking, even though the total stays above 1.
RESET ROLE;
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, quantity) VALUES
  (910107, 'B wish x3 lowered', '', 900003, '00000000-0000-4000-a000-00000000000b', 3);
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (910107, '00000000-0000-4000-a000-00000000000a', 2),
  (910107, '00000000-0000-4000-a000-00000000000c', 1);
-- Legacy over-booked state: the quantity trigger would refuse this update.
ALTER TABLE public.wishs DISABLE TRIGGER check_wish_quantity_not_below_booked;
UPDATE public.wishs SET quantity = 1 WHERE id = 910107;
ALTER TABLE public.wishs ENABLE TRIGGER check_wish_quantity_not_below_booked;
SET LOCAL ROLE authenticated;
SELECT pg_temp.expect_rows('own booking lowered on an over-booked wish',
  $q$UPDATE public.wish_taken_by_user SET quantity = 1 WHERE wish_id = 910107 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$, 1);

-- The owner B lowers the quantity of wish 910108 (4, booked 2 by A and 1 by C)
-- and of wish 910109 (3, not booked).
RESET ROLE;
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, quantity) VALUES
  (910108, 'B wish x4 booked', '', 900003, '00000000-0000-4000-a000-00000000000b', 4),
  (910109, 'B wish x3 free',   '', 900003, '00000000-0000-4000-a000-00000000000b', 3);
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (910108, '00000000-0000-4000-a000-00000000000a', 2),
  (910108, '00000000-0000-4000-a000-00000000000c', 1);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000b', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000b", "role": "authenticated"}', true);

CREATE FUNCTION pg_temp.expect_below_booked(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: allowed, expected wish_quantity_below_booked', label;
EXCEPTION WHEN check_violation THEN
  IF SQLERRM <> 'wish_quantity_below_booked' THEN RAISE; END IF;
  RAISE NOTICE 'ok   % (wish_quantity_below_booked)', label;
END $$;

SELECT pg_temp.expect_below_booked('quantity lowered below the booked total',
  $q$UPDATE public.wishs SET quantity = 2 WHERE id = 910108$q$);
SELECT pg_temp.expect_rows('quantity lowered to exactly the booked total',
  $q$UPDATE public.wishs SET quantity = 3 WHERE id = 910108$q$, 1);
SELECT pg_temp.expect_rows('quantity raised',
  $q$UPDATE public.wishs SET quantity = 5 WHERE id = 910108$q$, 1);
SELECT pg_temp.expect_rows('quantity lowered on a wish without booking',
  $q$UPDATE public.wishs SET quantity = 1 WHERE id = 910109$q$, 1);

-- restore_completed_wish: B restores two completed wishes of archived wishlists.
-- 910110 (quantity 4, received 1, booked 3 by A) comes back with 3, 910111
-- (quantity 4, received 2, booked 1 by A) comes back with 2.
RESET ROLE;
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility, is_closed, deleted_at) VALUES
  (900107, 'B archived 1', '00000000-0000-4000-a000-00000000000b', '#FFFFFF', '00000000-0000-4000-a000-00000000000b', 'public', false, now()),
  (900108, 'B archived 2', '00000000-0000-4000-a000-00000000000b', '#FFFFFF', '00000000-0000-4000-a000-00000000000b', 'public', false, now());
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, quantity) VALUES
  (910110, 'B completed booked above', '', 900107, '00000000-0000-4000-a000-00000000000b', 4),
  (910111, 'B completed booked below', '', 900108, '00000000-0000-4000-a000-00000000000b', 4);
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (910110, '00000000-0000-4000-a000-00000000000a', 3),
  (910111, '00000000-0000-4000-a000-00000000000a', 1);
INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity) VALUES
  ('00000000-0000-4000-a000-00000000000b', 910110, 900107, 1),
  ('00000000-0000-4000-a000-00000000000b', 910111, 900108, 2);
SET LOCAL ROLE authenticated;
SELECT public.restore_completed_wish(910110, 900003);
SELECT public.restore_completed_wish(910111, 900003);
RESET ROLE;
DO $$
BEGIN
  IF (SELECT quantity FROM public.wishs WHERE id = 910110) <> 3 THEN
    RAISE EXCEPTION 'FAIL restore with bookings above the received quantity: expected the booked total (3)';
  END IF;
  IF (SELECT quantity FROM public.wishs WHERE id = 910111) <> 2 THEN
    RAISE EXCEPTION 'FAIL restore with bookings below the received quantity: expected the received quantity (2)';
  END IF;
  RAISE NOTICE 'ok   restore_completed_wish keeps at least the booked total';
END $$;

-- Archived wishlist (F089, 20261018130000): A cannot book a wish of an
-- archived wishlist of B, nor update a booking made before the archiving, but
-- can cancel it. Once B restores the completed wish to an active wishlist, the
-- booking follows the wish and can be updated again.
RESET ROLE;
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility, is_closed, deleted_at) VALUES
  (900201, 'B archived 3', '00000000-0000-4000-a000-00000000000b', '#FFFFFF', '00000000-0000-4000-a000-00000000000b', 'public', false, now());
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, quantity) VALUES
  (910201, 'B completed not booked', '', 900201, '00000000-0000-4000-a000-00000000000b', 2),
  (910202, 'B completed booked',     '', 900201, '00000000-0000-4000-a000-00000000000b', 2),
  (910203, 'B completed restored',   '', 900201, '00000000-0000-4000-a000-00000000000b', 2);
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (910202, '00000000-0000-4000-a000-00000000000a', 1),
  (910203, '00000000-0000-4000-a000-00000000000a', 1);
INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity) VALUES
  ('00000000-0000-4000-a000-00000000000b', 910203, 900201, 2);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000a', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000a", "role": "authenticated"}', true);
SELECT pg_temp.expect_denied('booking in an archived wishlist',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910201, '00000000-0000-4000-a000-00000000000a', 1)$q$);
SELECT pg_temp.expect_denied('own booking updated in an archived wishlist',
  $q$UPDATE public.wish_taken_by_user SET quantity = 2 WHERE wish_id = 910202 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$);
SELECT pg_temp.expect_rows('own booking cancelled in an archived wishlist',
  $q$DELETE FROM public.wish_taken_by_user WHERE wish_id = 910202 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$, 1);
SELECT pg_temp.expect_denied('own booking updated before the restore',
  $q$UPDATE public.wish_taken_by_user SET quantity = 2 WHERE wish_id = 910203 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$);
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000b', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000b", "role": "authenticated"}', true);
SELECT public.restore_completed_wish(910203, 900003);
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000a', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000a", "role": "authenticated"}', true);
SELECT pg_temp.expect_rows('own booking updated after the restore to an active wishlist',
  $q$UPDATE public.wish_taken_by_user SET quantity = 2 WHERE wish_id = 910203 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$, 1);

-- A received quantity consumes the bookings first (20261018140000):
-- GREATEST(booked, received) <= quantity. B (owner) has wishes 910301 (quantity
-- 2, 1 received, no booking), 910302 (quantity 1, fully received), 910305
-- (quantity 3, booked 1 by A, 1 received) and 910303 (quantity 2, booked 2 by A,
-- received later by B).
RESET ROLE;
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, quantity) VALUES
  (910301, 'B wish x2 one received', '', 900003, '00000000-0000-4000-a000-00000000000b', 2),
  (910302, 'B wish fully received',  '', 900003, '00000000-0000-4000-a000-00000000000b', 1),
  (910303, 'B wish booked then received', '', 900003, '00000000-0000-4000-a000-00000000000b', 2),
  (910305, 'B wish x3 booked 1 received 1', '', 900003, '00000000-0000-4000-a000-00000000000b', 3);
INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity) VALUES
  ('00000000-0000-4000-a000-00000000000b', 910301, 900003, 1),
  ('00000000-0000-4000-a000-00000000000b', 910302, 900003, 1),
  ('00000000-0000-4000-a000-00000000000b', 910305, 900003, 1);
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (910303, '00000000-0000-4000-a000-00000000000a', 2),
  (910305, '00000000-0000-4000-a000-00000000000a', 1);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000a', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000a", "role": "authenticated"}', true);
SELECT pg_temp.expect_overbooked('booking of a fully received wish',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910302, '00000000-0000-4000-a000-00000000000a', 1)$q$);
SELECT pg_temp.expect_overbooked('booking above the pending quantity (2 with 1 received, nothing booked)',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910301, '00000000-0000-4000-a000-00000000000a', 2)$q$);
SELECT pg_temp.expect_rows('booking the pending quantity (1 with 1 received, nothing booked)',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910301, '00000000-0000-4000-a000-00000000000a', 1)$q$, 1);
SELECT pg_temp.expect_rows('booking raised to the quantity (booked 2 includes the received one)',
  $q$UPDATE public.wish_taken_by_user SET quantity = 2 WHERE wish_id = 910301 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$, 1);
SELECT pg_temp.expect_rows('own booking lowered (always allowed)',
  $q$UPDATE public.wish_taken_by_user SET quantity = 1 WHERE wish_id = 910301 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$, 1);
SELECT pg_temp.expect_overbooked('booking moved onto a fully received wish',
  $q$UPDATE public.wish_taken_by_user SET wish_id = 910302 WHERE wish_id = 910301 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$);

-- Booked 1 and received 1 on a quantity of 3: the received item is the booked
-- one, so 2 remain. C books 2 (total booked 3), a third booking is refused.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000c', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000c", "role": "authenticated"}', true);
SELECT pg_temp.expect_overbooked('booking 3 when 1 is booked and 1 received (quantity 3)',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910305, '00000000-0000-4000-a000-00000000000c', 3)$q$);
SELECT pg_temp.expect_rows('booking the 2 pending when 1 is booked and 1 received (quantity 3)',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910305, '00000000-0000-4000-a000-00000000000c', 2)$q$, 1);
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000a', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000a", "role": "authenticated"}', true);
SELECT pg_temp.expect_overbooked('raising a booking once booked reaches the quantity (quantity 3, booked 3)',
  $q$UPDATE public.wish_taken_by_user SET quantity = 2 WHERE wish_id = 910305 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$);

-- Marking as received is not blocked while bookings exist (910303: booked 2 by
-- A, quantity 2, owner receives 1 then 2).
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000b', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000b", "role": "authenticated"}', true);
SELECT pg_temp.expect_rows('marking received a wish booked in full (insert)',
  $q$INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity) VALUES ('00000000-0000-4000-a000-00000000000b', 910303, 900003, 1)$q$, 1);
SELECT pg_temp.expect_rows('raising the received quantity up to the bookings (update)',
  $q$UPDATE public.user_completed_wishs SET quantity = 2 WHERE wish_id = 910303$q$, 1);

-- The day of the completion: the current day when the insert does not give it
-- (app versions before 20261029100000), then changed by the owner. The other
-- columns stay out of reach.
DO $$
BEGIN
  IF (SELECT completed_at FROM public.user_completed_wishs WHERE wish_id = 910303)
     IS DISTINCT FROM (now() AT TIME ZONE 'Europe/Paris')::date THEN
    RAISE EXCEPTION 'FAIL completion day defaults to the current day';
  END IF;
  RAISE NOTICE 'ok   completion day defaults to the current day';
END $$;
SELECT pg_temp.expect_rows('completion day changed (update)',
  $q$UPDATE public.user_completed_wishs SET completed_at = '2026-01-15' WHERE wish_id = 910303$q$, 1);
SELECT pg_temp.expect_denied('completion insert time changed (update)',
  $q$UPDATE public.user_completed_wishs SET created_at = now() - interval '1 day' WHERE wish_id = 910303$q$);
SELECT pg_temp.expect_denied('completion moved to another wishlist (update)',
  $q$UPDATE public.user_completed_wishs SET from_wishlist_id = 900003 WHERE wish_id = 910303$q$);

-- A still lowers a booking of a wish booked and received in full (910303:
-- booked 2, received 2, quantity 2); raising it back is refused, and so is a
-- new booking of C (GREATEST(1, 2) + 1 > 2).
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000a', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000a", "role": "authenticated"}', true);
SELECT pg_temp.expect_rows('own booking lowered on a wish booked and received in full',
  $q$UPDATE public.wish_taken_by_user SET quantity = 1 WHERE wish_id = 910303 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$, 1);
SELECT pg_temp.expect_overbooked('own booking raised back (received 2 leaves nothing to book)',
  $q$UPDATE public.wish_taken_by_user SET quantity = 2 WHERE wish_id = 910303 AND user_id = '00000000-0000-4000-a000-00000000000a'$q$);
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000c', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000c", "role": "authenticated"}', true);
SELECT pg_temp.expect_overbooked('new booking on a wish with nothing pending (booked 1, received 2)',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910303, '00000000-0000-4000-a000-00000000000c', 1)$q$);

-- Only the owner's completion counts: a completion row of another user on the
-- wish (possible before the insert policy of 20260516000000) does not block
-- the bookings (910304, quantity 1, "received" by C).
RESET ROLE;
INSERT INTO public.wishs (id, name, description, wishlist_id, updated_by, quantity) VALUES
  (910304, 'B wish completed by C', '', 900003, '00000000-0000-4000-a000-00000000000b', 1);
INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity) VALUES
  ('00000000-0000-4000-a000-00000000000c', 910304, 900003, 1);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-00000000000a', true);
SELECT set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-a000-00000000000a", "role": "authenticated"}', true);
SELECT pg_temp.expect_rows('booking a wish whose only completion is not the owner''s',
  $q$INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910304, '00000000-0000-4000-a000-00000000000a', 1)$q$, 1);

-- Quantity 0 is refused by the booking policy and by the CHECK constraint.
RESET ROLE;
DO $$
BEGIN
  INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES (910006, '00000000-0000-4000-a000-00000000000a', 0);
  RAISE EXCEPTION 'FAIL quantity 0 accepted by the table';
EXCEPTION WHEN check_violation THEN
  IF SQLERRM NOT LIKE '%wish_taken_by_user_quantity_positive%' THEN RAISE; END IF;
  RAISE NOTICE 'ok   quantity 0 refused by the CHECK constraint';
END $$;

ROLLBACK;
