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
