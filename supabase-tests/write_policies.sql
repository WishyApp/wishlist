-- Write policies of wishlists, wishs and wish_taken_by_user
-- (20261011000000_restrict_write_policies_to_owner).
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

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

ROLLBACK;
