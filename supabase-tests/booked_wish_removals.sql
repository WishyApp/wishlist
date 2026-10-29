-- Rules of booked_wish_removals (20261030100002_booked_wish_removals).
--
-- The triggers on wishs and wishlists record, for each person who booked a
-- wish, that the owner removed it. They must never make a deletion fail, and
-- must record nothing when the deletion comes from an account deletion
-- (auth.users -> profiles -> wishlists -> wishs), where the parent rows are no
-- longer visible from the BEFORE DELETE triggers of the children.
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

-- Functions created by postgres have no EXECUTE for PUBLIC by default
-- (20261012110000_restrict_anon_privileges): the helpers below are called
-- after switching role. Rolled back with the rest.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

CREATE FUNCTION pg_temp.expect_denied(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: allowed, expected a denial', label;
EXCEPTION WHEN insufficient_privilege OR check_violation OR not_null_violation THEN
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

-- Expects the number of rows of a SELECT count(*), with the current role.
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

-- The after-the-party window depends on the day the test runs (now() is fixed
-- in the transaction, and a run in late December or on the owner's birthday
-- would silently record nothing). paris_today() is replaced, until the
-- rollback, by a day with no window; the cases of the window set their own day.
CREATE OR REPLACE FUNCTION public.paris_today()
RETURNS date LANGUAGE sql STABLE AS $$ SELECT DATE '2026-06-01' $$;

-- Fixtures. O owns the wishlists, A and B are friends who book wishes.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-d000-0000000000f1'),
  ('00000000-0000-4000-d000-0000000000f2'),
  ('00000000-0000-4000-d000-0000000000f3');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-d000-0000000000f1', 'bwr_owner'),
  ('00000000-0000-4000-d000-0000000000f2', 'bwr_a'),
  ('00000000-0000-4000-d000-0000000000f3', 'bwr_b');

-- Wishlist 980001: W1 (quantity 2, booked 2 by A), W2 (booked by A and B),
-- W3 (booked by B, received by O).
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility) VALUES
  (980001, 'Birthday list', '00000000-0000-4000-d000-0000000000f1', '#FFFFFF', '00000000-0000-4000-d000-0000000000f1', 'public');
INSERT INTO public.wishs (id, name, description, quantity, wishlist_id, updated_by) VALUES
  (981001, 'W1 board game', '', 2, 980001, '00000000-0000-4000-d000-0000000000f1'),
  (981002, 'W2 book',       '', 4, 980001, '00000000-0000-4000-d000-0000000000f1'),
  (981003, 'W3 mug',        '', 1, 980001, '00000000-0000-4000-d000-0000000000f1');
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (981001, '00000000-0000-4000-d000-0000000000f2', 2),
  (981002, '00000000-0000-4000-d000-0000000000f2', 1),
  (981002, '00000000-0000-4000-d000-0000000000f3', 1),
  (981003, '00000000-0000-4000-d000-0000000000f3', 1);
INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity) VALUES
  ('00000000-0000-4000-d000-0000000000f1', 981003, 980001, 1);

-- 1. A single wish deleted by its owner.
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000f1');
SELECT pg_temp.expect_rows('owner deletes W1',
  $q$DELETE FROM public.wishs WHERE id = 981001$q$, 1);
RESET ROLE;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.booked_wish_removals
    WHERE booker_id = '00000000-0000-4000-d000-0000000000f2'
      AND owner_id = '00000000-0000-4000-d000-0000000000f1'
      AND wish_id = 981001 AND wish_name = 'W1 board game' AND quantity = 2
      AND wishlist_name = 'Birthday list'
      AND removed_at IS NOT NULL AND dismissed_at IS NULL
  ) THEN
    RAISE EXCEPTION 'FAIL deleting W1 did not record the removal for A';
  END IF;
  IF EXISTS (SELECT 1 FROM public.booked_wish_removals
             WHERE booker_id = '00000000-0000-4000-d000-0000000000f3') THEN
    RAISE EXCEPTION 'FAIL deleting W1 recorded a removal for B, who did not book it';
  END IF;
  RAISE NOTICE 'ok   deleting a booked wish records one removal for its booker';
END $$;

-- 2. A wish already received: the gift was given, no alert.
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000f1');
SELECT pg_temp.expect_rows('owner deletes the received W3',
  $q$DELETE FROM public.wishs WHERE id = 981003$q$, 1);
RESET ROLE;
SELECT pg_temp.expect_count('no removal for a received wish',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE wish_id = 981003$q$, 0);

-- 3. Two bookers on the same wish.
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000f1');
SELECT pg_temp.expect_rows('owner deletes W2',
  $q$DELETE FROM public.wishs WHERE id = 981002$q$, 1);
RESET ROLE;
SELECT pg_temp.expect_count('W2 recorded for A and B',
  $q$SELECT count(DISTINCT booker_id) FROM public.booked_wish_removals WHERE wish_id = 981002$q$, 2);
SELECT pg_temp.expect_count('W2 records the booked quantity (1), not the wish quantity (4), for A and B',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE wish_id = 981002 AND quantity = 1$q$, 2);
SELECT pg_temp.expect_count('W2 recorded once per booking',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE wish_id = 981002$q$, 2);

-- 4. A whole wishlist deleted: the wishs are removed by the cascade, when the
-- wishlist is no longer visible. The wishlist trigger records them, once.
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility) VALUES
  (980002, 'Wishlist to delete', '00000000-0000-4000-d000-0000000000f1', '#FFFFFF', '00000000-0000-4000-d000-0000000000f1', 'public');
INSERT INTO public.wishs (id, name, description, quantity, wishlist_id, updated_by) VALUES
  (981004, 'W4 lamp', '', 1, 980002, '00000000-0000-4000-d000-0000000000f1');
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (981004, '00000000-0000-4000-d000-0000000000f2', 1);
DELETE FROM public.wishlists WHERE id = 980002;
DO $$
BEGIN
  IF (SELECT count(*) FROM public.booked_wish_removals
      WHERE wish_id = 981004 AND booker_id = '00000000-0000-4000-d000-0000000000f2'
        AND wish_name = 'W4 lamp' AND wishlist_name = 'Wishlist to delete'
        AND owner_id = '00000000-0000-4000-d000-0000000000f1') <> 1 THEN
    RAISE EXCEPTION 'FAIL deleting a wishlist must record W4 exactly once for A';
  END IF;
  RAISE NOTICE 'ok   deleting a wishlist records its booked wishes once';
END $$;

-- 5. delete_or_archive_wishlist: a list with a received wish is archived, the
-- other wishes are deleted and recorded; a list without one is deleted.
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility) VALUES
  (980003, 'Archived list', '00000000-0000-4000-d000-0000000000f1', '#FFFFFF', '00000000-0000-4000-d000-0000000000f1', 'public'),
  (980004, 'Deleted list',  '00000000-0000-4000-d000-0000000000f1', '#FFFFFF', '00000000-0000-4000-d000-0000000000f1', 'public');
INSERT INTO public.wishs (id, name, description, quantity, wishlist_id, updated_by) VALUES
  (981005, 'W5 plant',    '', 1, 980003, '00000000-0000-4000-d000-0000000000f1'),
  (981006, 'W6 received', '', 1, 980003, '00000000-0000-4000-d000-0000000000f1'),
  (981007, 'W7 scarf',    '', 1, 980004, '00000000-0000-4000-d000-0000000000f1');
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (981005, '00000000-0000-4000-d000-0000000000f3', 1),
  (981007, '00000000-0000-4000-d000-0000000000f3', 1);
INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity) VALUES
  ('00000000-0000-4000-d000-0000000000f1', 981006, 980003, 1);
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000f1');
SELECT public.delete_or_archive_wishlist(980003);
SELECT public.delete_or_archive_wishlist(980004);
RESET ROLE;
DO $$
BEGIN
  IF (SELECT deleted_at FROM public.wishlists WHERE id = 980003) IS NULL THEN
    RAISE EXCEPTION 'FAIL the wishlist with a received wish must be archived';
  END IF;
  IF EXISTS (SELECT 1 FROM public.wishlists WHERE id = 980004) THEN
    RAISE EXCEPTION 'FAIL the wishlist without a received wish must be deleted';
  END IF;
  IF (SELECT count(*) FROM public.booked_wish_removals
      WHERE wish_id = 981005 AND booker_id = '00000000-0000-4000-d000-0000000000f3'
        AND wishlist_name = 'Archived list') <> 1 THEN
    RAISE EXCEPTION 'FAIL archiving must record W5 exactly once for B';
  END IF;
  IF (SELECT count(*) FROM public.booked_wish_removals
      WHERE wish_id = 981007 AND booker_id = '00000000-0000-4000-d000-0000000000f3'
        AND wishlist_name = 'Deleted list') <> 1 THEN
    RAISE EXCEPTION 'FAIL deleting a wishlist through delete_or_archive_wishlist must record W7 exactly once for B';
  END IF;
  IF EXISTS (SELECT 1 FROM public.booked_wish_removals WHERE wish_id = 981006) THEN
    RAISE EXCEPTION 'FAIL the received wish of an archived wishlist must not be recorded';
  END IF;
  RAISE NOTICE 'ok   delete_or_archive_wishlist records the wishes it deletes';
END $$;

-- 6. A booking of the owner on their own wish is not an alert.
INSERT INTO public.wishs (id, name, description, quantity, wishlist_id, updated_by) VALUES
  (981008, 'W8 self booked', '', 1, 980003, '00000000-0000-4000-d000-0000000000f1');
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (981008, '00000000-0000-4000-d000-0000000000f1', 1);
DELETE FROM public.wishs WHERE id = 981008;
SELECT pg_temp.expect_count('no removal for a booking of the owner',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE wish_id = 981008$q$, 0);

-- 7. Policies and privileges, before the account deletion that wipes O's rows.
SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000f2');
SELECT pg_temp.expect_count('A reads only their own removals',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE booker_id <> auth.uid()$q$, 0);
SELECT pg_temp.expect_count('A reads their removals (W1, W2, W4)',
  $q$SELECT count(*) FROM public.booked_wish_removals$q$, 3);
SELECT pg_temp.expect_rows('A dismisses their removal',
  $q$UPDATE public.booked_wish_removals SET dismissed_at = now() WHERE wish_id = 981001$q$, 1);
SELECT pg_temp.expect_denied('A edits the name of their removal',
  $q$UPDATE public.booked_wish_removals SET wish_name = 'x' WHERE wish_id = 981001$q$);
SELECT pg_temp.expect_rows('A dismisses the removal of B (invisible)',
  $q$UPDATE public.booked_wish_removals SET dismissed_at = now() WHERE wish_id = 981007$q$, 0);
SELECT pg_temp.expect_denied('A inserts a removal',
  $q$INSERT INTO public.booked_wish_removals (booker_id, owner_id, wish_id, wish_name, quantity, wishlist_name)
     VALUES (auth.uid(), '00000000-0000-4000-d000-0000000000f1', 1, 'x', 1, 'x')$q$);
SELECT pg_temp.expect_denied('A deletes a removal',
  $q$DELETE FROM public.booked_wish_removals WHERE wish_id = 981001$q$);
SELECT pg_temp.expect_denied('A calls the internal recording function',
  $q$SELECT public.record_booked_wish_removals(ARRAY[981002]::bigint[], '00000000-0000-4000-d000-0000000000f1', 'x')$q$);
RESET ROLE;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.booked_wish_removals
                 WHERE wish_id = 981007 AND dismissed_at IS NULL) THEN
    RAISE EXCEPTION 'FAIL the removal of B was dismissed by A';
  END IF;
  RAISE NOTICE 'ok   the removal of B is untouched by A';
END $$;

-- 8. Account deletion: a cascade auth.users -> profiles -> wishlists -> wishs
-- records nothing for the friends who booked, and the removals whose owner is
-- the deleted user disappear with it.
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility) VALUES
  (980005, 'Account list', '00000000-0000-4000-d000-0000000000f1', '#FFFFFF', '00000000-0000-4000-d000-0000000000f1', 'public');
INSERT INTO public.wishs (id, name, description, quantity, wishlist_id, updated_by) VALUES
  (981009, 'W9 account', '', 1, 980005, '00000000-0000-4000-d000-0000000000f1');
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (981009, '00000000-0000-4000-d000-0000000000f2', 1);
DELETE FROM auth.users WHERE id = '00000000-0000-4000-d000-0000000000f1';
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.wishlists WHERE id_owner = '00000000-0000-4000-d000-0000000000f1')
     OR EXISTS (SELECT 1 FROM public.wishs WHERE id IN (981005, 981009)) THEN
    RAISE EXCEPTION 'FAIL the account deletion did not cascade to the wishlists and wishs';
  END IF;
  IF EXISTS (SELECT 1 FROM public.booked_wish_removals WHERE wish_id = 981009) THEN
    RAISE EXCEPTION 'FAIL an account deletion recorded a removal (cascade visibility assumption broken)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.booked_wish_removals
             WHERE owner_id = '00000000-0000-4000-d000-0000000000f1') THEN
    RAISE EXCEPTION 'FAIL the removals of the deleted owner must disappear with the account';
  END IF;
  RAISE NOTICE 'ok   an account deletion records nothing and removes the alerts about its owner';
END $$;

-- 9. The booker deletes their account: their removals disappear, the
-- deletions still work.
INSERT INTO auth.users (id) VALUES ('00000000-0000-4000-d000-0000000000f4');
INSERT INTO public.profiles (id, pseudo) VALUES ('00000000-0000-4000-d000-0000000000f4', 'bwr_o2');
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility) VALUES
  (980006, 'O2 list', '00000000-0000-4000-d000-0000000000f4', '#FFFFFF', '00000000-0000-4000-d000-0000000000f4', 'public');
INSERT INTO public.wishs (id, name, description, quantity, wishlist_id, updated_by) VALUES
  (981010, 'W10', '', 1, 980006, '00000000-0000-4000-d000-0000000000f4');
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (981010, '00000000-0000-4000-d000-0000000000f2', 1);
DELETE FROM public.wishs WHERE id = 981010;
SELECT pg_temp.expect_count('W10 recorded for A',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE wish_id = 981010$q$, 1);
DELETE FROM auth.users WHERE id = '00000000-0000-4000-d000-0000000000f2';
SELECT pg_temp.expect_count('removals of a deleted booker disappear',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE booker_id = '00000000-0000-4000-d000-0000000000f2'$q$, 0);

-- 9b. Partially received wish: all the bookers are alerted while the owner
-- received less than the total booked, nobody when it is equal or higher.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-d000-0000000000f5'),
  ('00000000-0000-4000-d000-0000000000f6'),
  ('00000000-0000-4000-d000-0000000000f7');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-d000-0000000000f5', 'bwr_o3'),
  ('00000000-0000-4000-d000-0000000000f6', 'bwr_c'),
  ('00000000-0000-4000-d000-0000000000f7', 'bwr_d');
INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility) VALUES
  (980007, 'O3 list', '00000000-0000-4000-d000-0000000000f5', '#FFFFFF', '00000000-0000-4000-d000-0000000000f5', 'public');
INSERT INTO public.wishs (id, name, description, quantity, wishlist_id, updated_by) VALUES
  (981020, 'W20 received 1 of 3', '', 3, 980007, '00000000-0000-4000-d000-0000000000f5'),
  (981021, 'W21 received 2 of 3', '', 3, 980007, '00000000-0000-4000-d000-0000000000f5');
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (981020, '00000000-0000-4000-d000-0000000000f6', 1),
  (981020, '00000000-0000-4000-d000-0000000000f7', 1),
  (981021, '00000000-0000-4000-d000-0000000000f6', 1),
  (981021, '00000000-0000-4000-d000-0000000000f7', 1);
INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity) VALUES
  ('00000000-0000-4000-d000-0000000000f5', 981020, 980007, 1),
  ('00000000-0000-4000-d000-0000000000f5', 981021, 980007, 2);
DELETE FROM public.wishs WHERE id IN (981020, 981021);
SELECT pg_temp.expect_count('received 1 of 3 booked 2: both bookers alerted',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE wish_id = 981020 AND quantity = 1$q$, 2);
SELECT pg_temp.expect_count('received 2 of 3 booked 2: nobody alerted',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE wish_id = 981021$q$, 0);

-- 9c. is_after_party_window on fixed dates. Owner f5, no birthday first.
SELECT pg_temp.expect_count('Dec 24: no window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-12-24')) x$q$, 0);
SELECT pg_temp.expect_count('Dec 25: window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-12-25')) x$q$, 1);
SELECT pg_temp.expect_count('Jan 24: window (Christmas + 30)',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2027-01-24')) x$q$, 1);
SELECT pg_temp.expect_count('Jan 25: no window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2027-01-25')) x$q$, 0);
SELECT pg_temp.expect_count('no birthday, Jun 1: no window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-06-01')) x$q$, 0);

INSERT INTO public.profile_birthdays (profile_id, month, day)
  VALUES ('00000000-0000-4000-d000-0000000000f5', 3, 10);
SELECT pg_temp.expect_count('birthday Mar 10, Mar 9: no window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-03-09')) x$q$, 0);
SELECT pg_temp.expect_count('birthday Mar 10, Mar 10: window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-03-10')) x$q$, 1);
SELECT pg_temp.expect_count('birthday Mar 10, Apr 9: window (+30)',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-04-09')) x$q$, 1);
SELECT pg_temp.expect_count('birthday Mar 10, Apr 10: no window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-04-10')) x$q$, 0);

-- A birthday just before the new year covers days of the next one. Dec 20
-- alone cannot show it (Jan 19 is already in the Christmas window, which ends
-- on Jan 24), so Dec 31 is used: the window goes to Jan 30, the previous
-- year's birthday counts.
UPDATE public.profile_birthdays SET month = 12, day = 20
  WHERE profile_id = '00000000-0000-4000-d000-0000000000f5';
SELECT pg_temp.expect_count('birthday Dec 20, Jan 19 of the next year: window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2027-01-19')) x$q$, 1);
SELECT pg_temp.expect_count('birthday Dec 20, Dec 19: no window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-12-19')) x$q$, 0);
UPDATE public.profile_birthdays SET month = 11, day = 20
  WHERE profile_id = '00000000-0000-4000-d000-0000000000f5';
SELECT pg_temp.expect_count('birthday Nov 20, Dec 20: window (+30)',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-12-20')) x$q$, 1);
SELECT pg_temp.expect_count('birthday Nov 20, Dec 21: no window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-12-21')) x$q$, 0);
UPDATE public.profile_birthdays SET month = 12, day = 31
  WHERE profile_id = '00000000-0000-4000-d000-0000000000f5';
SELECT pg_temp.expect_count('birthday Dec 31, Jan 30 of the next year: window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2027-01-30')) x$q$, 1);
SELECT pg_temp.expect_count('birthday Dec 31, Jan 31 of the next year: no window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2027-01-31')) x$q$, 0);

-- Feb 29 exists in no common year: it counts as Feb 28 there.
UPDATE public.profile_birthdays SET month = 2, day = 29
  WHERE profile_id = '00000000-0000-4000-d000-0000000000f5';
SELECT pg_temp.expect_count('birthday Feb 29, Feb 28 of a common year: window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2027-02-28')) x$q$, 1);
SELECT pg_temp.expect_count('birthday Feb 29, Feb 27 of a common year: no window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2027-02-27')) x$q$, 0);
SELECT pg_temp.expect_count('birthday Feb 29, Feb 29 of a leap year: window',
  $q$SELECT count(*) FROM (SELECT 1 WHERE public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2028-02-29')) x$q$, 1);

SELECT pg_temp.act_as('00000000-0000-4000-d000-0000000000f6');
SELECT pg_temp.expect_denied('a user calls is_after_party_window',
  $q$SELECT public.is_after_party_window('00000000-0000-4000-d000-0000000000f5', DATE '2026-12-25')$q$);
RESET ROLE;

-- 9d. End to end: a deletion inside the window records nothing.
-- Christmas window (Dec 26), then the owner's birthday window.
INSERT INTO public.wishs (id, name, description, quantity, wishlist_id, updated_by) VALUES
  (981022, 'W22 after Christmas', '', 1, 980007, '00000000-0000-4000-d000-0000000000f5'),
  (981023, 'W23 after the birthday', '', 1, 980007, '00000000-0000-4000-d000-0000000000f5'),
  (981024, 'W24 outside the window', '', 1, 980007, '00000000-0000-4000-d000-0000000000f5');
INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity) VALUES
  (981022, '00000000-0000-4000-d000-0000000000f6', 1),
  (981023, '00000000-0000-4000-d000-0000000000f6', 1),
  (981024, '00000000-0000-4000-d000-0000000000f6', 1);
CREATE OR REPLACE FUNCTION public.paris_today()
RETURNS date LANGUAGE sql STABLE AS $$ SELECT DATE '2026-12-26' $$;
DELETE FROM public.wishs WHERE id = 981022;
SELECT pg_temp.expect_count('no removal the day after Christmas',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE wish_id = 981022$q$, 0);
CREATE OR REPLACE FUNCTION public.paris_today()
RETURNS date LANGUAGE sql STABLE AS $$ SELECT DATE '2026-06-01' $$;
UPDATE public.profile_birthdays SET month = 5, day = 25
  WHERE profile_id = '00000000-0000-4000-d000-0000000000f5';
DELETE FROM public.wishs WHERE id = 981023;
SELECT pg_temp.expect_count('no removal 7 days after the birthday',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE wish_id = 981023$q$, 0);
UPDATE public.profile_birthdays SET month = 4, day = 1
  WHERE profile_id = '00000000-0000-4000-d000-0000000000f5';
DELETE FROM public.wishs WHERE id = 981024;
SELECT pg_temp.expect_count('a removal outside both windows is recorded',
  $q$SELECT count(*) FROM public.booked_wish_removals WHERE wish_id = 981024$q$, 1);

-- 10. Realtime prerequisites, as in friendships_realtime.sql: the app filters
-- its channel on booker_id, UPDATEs included.
DO $$
BEGIN
  IF (SELECT relreplident FROM pg_class
      WHERE oid = 'public.booked_wish_removals'::regclass) <> 'f' THEN
    RAISE EXCEPTION 'FAIL booked_wish_removals must be REPLICA IDENTITY FULL';
  END IF;
  RAISE NOTICE 'ok   booked_wish_removals is REPLICA IDENTITY FULL';

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'booked_wish_removals'
  ) THEN
    RAISE EXCEPTION 'FAIL booked_wish_removals must be in the supabase_realtime publication';
  END IF;
  RAISE NOTICE 'ok   booked_wish_removals is published to Realtime';
END $$;

ROLLBACK;
