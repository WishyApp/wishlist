-- Read rule of wish_taken_by_user
-- (20261018100000_restrict_booking_reads).
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

-- Functions created by postgres have no EXECUTE for PUBLIC by default
-- (20261012110000_restrict_anon_privileges): the helpers below are called
-- after switching role. Rolled back with the rest.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

-- Expects the number of rows a SELECT returns, with the current role.
CREATE FUNCTION pg_temp.expect_count(label text, statement text, expected int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  n int;
BEGIN
  EXECUTE statement INTO n;
  IF n <> expected THEN
    RAISE EXCEPTION 'FAIL %: % row(s), expected %', label, n, expected;
  END IF;
  RAISE NOTICE 'ok   % (% row(s))', label, n;
END $$;

CREATE FUNCTION pg_temp.act_as(user_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', user_id::text, true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
END $$;

-- Fixtures:
--   O1: owner, public wishlist, can_owner_see_taken_wish false.
--   O2: owner, public wishlist, can_owner_see_taken_wish true.
--   O3: owner, private wishlist, can_owner_see_taken_wish true.
--   O4: owner, private wishlist, can_owner_see_taken_wish false.
--   B1, B2: bookers (B1 books in all four wishlists, B2 in the first one).
--   B3: books the wish of the private wishlist of O3, as B1 does.
--   R: reader with no booking, S: stranger with no booking.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-d000-0000000000a1'),
  ('00000000-0000-4000-d000-0000000000a2'),
  ('00000000-0000-4000-d000-0000000000a3'),
  ('00000000-0000-4000-d000-0000000000a4'),
  ('00000000-0000-4000-d000-0000000000b1'),
  ('00000000-0000-4000-d000-0000000000b2'),
  ('00000000-0000-4000-d000-0000000000b3'),
  ('00000000-0000-4000-d000-0000000000c1'),
  ('00000000-0000-4000-d000-0000000000c2');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-d000-0000000000a1', 'book_o1'),
  ('00000000-0000-4000-d000-0000000000a2', 'book_o2'),
  ('00000000-0000-4000-d000-0000000000a3', 'book_o3'),
  ('00000000-0000-4000-d000-0000000000a4', 'book_o4'),
  ('00000000-0000-4000-d000-0000000000b1', 'book_b1'),
  ('00000000-0000-4000-d000-0000000000b2', 'book_b2'),
  ('00000000-0000-4000-d000-0000000000b3', 'book_b3'),
  ('00000000-0000-4000-d000-0000000000c1', 'book_r'),
  ('00000000-0000-4000-d000-0000000000c2', 'book_s');
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility, can_owner_see_taken_wish) VALUES
  (960001, 'O1 public, hidden',  '00000000-0000-4000-d000-0000000000a1', '#FFFFFF', '00000000-0000-4000-d000-0000000000a1', 'public',  false),
  (960002, 'O2 public, visible', '00000000-0000-4000-d000-0000000000a2', '#FFFFFF', '00000000-0000-4000-d000-0000000000a2', 'public',  true),
  (960003, 'O3 private, visible','00000000-0000-4000-d000-0000000000a3', '#FFFFFF', '00000000-0000-4000-d000-0000000000a3', 'private', true),
  (960004, 'O4 private, hidden', '00000000-0000-4000-d000-0000000000a4', '#FFFFFF', '00000000-0000-4000-d000-0000000000a4', 'private', false);
INSERT INTO public.wishs (id, name, description, quantity, wishlist_id, updated_by) VALUES
  (970001, 'O1 wish', '', 3, 960001, '00000000-0000-4000-d000-0000000000a1'),
  (970002, 'O2 wish', '', 3, 960002, '00000000-0000-4000-d000-0000000000a2'),
  (970003, 'O3 wish', '', 3, 960003, '00000000-0000-4000-d000-0000000000a3'),
  (970004, 'O4 wish', '', 3, 960004, '00000000-0000-4000-d000-0000000000a4');
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (970001, '00000000-0000-4000-d000-0000000000b1', 1),
  (970001, '00000000-0000-4000-d000-0000000000b2', 1),
  (970002, '00000000-0000-4000-d000-0000000000b1', 1),
  (970003, '00000000-0000-4000-d000-0000000000b1', 1),
  (970003, '00000000-0000-4000-d000-0000000000b3', 1),
  (970004, '00000000-0000-4000-d000-0000000000b1', 1);

-- As O1: the owner of a public wishlist that hides its bookings
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000a1');
SELECT pg_temp.expect_count('owner with can_owner_see_taken_wish false reads no booking',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id = 970001$q$, 0);
SELECT pg_temp.expect_count('owner with false reads no booking through the wish embed',
  $q$SELECT count(*) FROM public.wishs w JOIN public.wish_taken_by_user t ON t.wish_id = w.id
      WHERE w.wishlist_id = 960001$q$, 0);
SELECT pg_temp.expect_count('owner with false still reads the wish',
  $q$SELECT count(*) FROM public.wishs WHERE id = 970001$q$, 1);
SELECT pg_temp.expect_count('owner with false does not read the profile of a booker (B2 booked nothing else)',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-d000-0000000000b2'$q$, 0);
SELECT pg_temp.expect_count('owner with false reads, as a reader, only the booking of the other public wishlist',
  $q$SELECT count(*) FROM public.wish_taken_by_user$q$, 1);

-- As O2, O3: the owners who allow it
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000a2');
SELECT pg_temp.expect_count('owner with true reads the bookings of a public wishlist',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id = 970002$q$, 1);
SELECT pg_temp.expect_count('owner with true reads the profile of the booker',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-d000-0000000000b1'$q$, 1);
SELECT pg_temp.expect_count('owner with true reads, as a reader, the bookings of the other public wishlist only',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id <> 970002$q$, 2);
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000a3');
SELECT pg_temp.expect_count('owner with true reads the bookings of a private wishlist',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id = 970003$q$, 2);
SELECT pg_temp.expect_count('owner with true of a private wishlist reads the profile of a booker',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-d000-0000000000b3'$q$, 1);

-- As O4: private wishlist, hidden
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000a4');
SELECT pg_temp.expect_count('owner with false of a private wishlist reads no booking',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id = 970004$q$, 0);

-- As R: a reader with no booking sees the bookings of public wishlists, to
-- compute the available quantity, whatever the flag of the owner
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000c1');
SELECT pg_temp.expect_count('reader reads the bookings of a public wishlist with the flag false',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id = 970001$q$, 2);
SELECT pg_temp.expect_count('reader reads the bookings of a public wishlist with the flag true',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id = 970002$q$, 1);
SELECT pg_temp.expect_count('reader does not read the bookings of private wishlists',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id IN (970003, 970004)$q$, 0);
SELECT pg_temp.expect_count('reader reads the profile of a booker of a public wishlist',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-d000-0000000000b2'$q$, 1);

-- As B1: the booker reads their own bookings, even in a private wishlist, and
-- the other bookings of a public wishlist
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000b1');
SELECT pg_temp.expect_count('booker reads their own bookings',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE user_id = '00000000-0000-4000-d000-0000000000b1'$q$, 4);
SELECT pg_temp.expect_count('booker reads the other booking of a public wish',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id = 970001$q$, 2);
-- The query of the booked wishes screen
SELECT pg_temp.expect_count('booked wishes screen query still returns every booking',
  $q$SELECT count(*) FROM public.wish_taken_by_user t
       JOIN public.wishs w ON w.id = t.wish_id
       JOIN public.wishlists wl ON wl.id = w.wishlist_id
      WHERE t.user_id = '00000000-0000-4000-d000-0000000000b1'$q$, 4);

SELECT pg_temp.expect_count('booker does not read the other booking of a private wish',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id = 970003$q$, 1);
SELECT pg_temp.expect_count('booker does not read the profile of the other booker of a private wish',
  $q$SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-4000-d000-0000000000b3'$q$, 0);

-- As B2: books only one wish, reads only that booking among private wishlists
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000b2');
SELECT pg_temp.expect_count('booker of a public wish does not read bookings of private wishlists',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id IN (970003, 970004)$q$, 0);

-- As S: a stranger who reads a private wishlist's bookings sees nothing
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000c2');
SELECT pg_temp.expect_count('stranger does not read the bookings of a private wishlist',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id = 970003$q$, 0);

-- As R: what the app sends, PostgREST turns insert().select() and
-- update().select() into INSERT/UPDATE ... RETURNING, which checks the SELECT
-- policy on the new row.
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000c1');
SELECT pg_temp.expect_count('booking created with RETURNING in a hidden public wishlist',
  $q$WITH r AS (
       INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity)
       VALUES (970001, '00000000-0000-4000-d000-0000000000c1', 1)
       RETURNING *)
     SELECT count(*) FROM r$q$, 1);
SELECT pg_temp.expect_count('booking updated with RETURNING',
  $q$WITH r AS (
       UPDATE public.wish_taken_by_user SET quantity = 2
        WHERE wish_id = 970001 AND user_id = '00000000-0000-4000-d000-0000000000c1'
       RETURNING *)
     SELECT count(*) FROM r$q$, 1);
SELECT pg_temp.expect_count('booking deleted by its booker',
  $q$WITH r AS (
       DELETE FROM public.wish_taken_by_user WHERE wish_id = 970001
        AND user_id = '00000000-0000-4000-d000-0000000000c1'
       RETURNING *)
     SELECT count(*) FROM r$q$, 1);

-- As O1: the flag is the owner's setting, turning it on shows the bookings
-- already made
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000a1');
UPDATE public.wishlists
   SET can_owner_see_taken_wish = true,
       updated_by = '00000000-0000-4000-d000-0000000000a1'
 WHERE id = 960001;
SELECT pg_temp.expect_count('owner reads the bookings once the flag is turned on',
  $q$SELECT count(*) FROM public.wish_taken_by_user WHERE wish_id = 970001$q$, 2);

ROLLBACK;
