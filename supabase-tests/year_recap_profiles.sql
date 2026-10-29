-- year_recap_profiles (20261101100000_year_recap_profiles): seeds, stats,
-- scoring, grants.
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error. Year under test: 2026 (Paris).

BEGIN;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

CREATE FUNCTION pg_temp.expect_eq(label text, actual text, expected text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'FAIL %: got %, expected %', label, actual, expected;
  END IF;
  RAISE NOTICE 'ok   %', label;
END $$;

CREATE FUNCTION pg_temp.expect_denied(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: allowed, expected a denial', label;
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'ok   % (denied)', label;
END $$;

CREATE FUNCTION pg_temp.expect_sqlstate(label text, statement text, state text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: accepted, expected SQLSTATE %', label, state;
EXCEPTION WHEN OTHERS THEN
  IF SQLSTATE = state THEN
    RAISE NOTICE 'ok   % (SQLSTATE %)', label, state;
  ELSE
    RAISE EXCEPTION 'FAIL %: SQLSTATE %, expected % (%)', label, SQLSTATE, state, SQLERRM;
  END IF;
END $$;

CREATE FUNCTION pg_temp.act_as_anon()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
END $$;

CREATE FUNCTION pg_temp.act_as(user_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', COALESCE(user_id::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
END $$;

-- Test data builders. Users are numbered: u(n) creates user n on first use.
CREATE FUNCTION pg_temp.u(n int) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  v uuid := ('00000000-0000-4000-d000-' || lpad(n::text, 12, '0'))::uuid;
BEGIN
  INSERT INTO auth.users (id) VALUES (v) ON CONFLICT DO NOTHING;
  INSERT INTO public.profiles (id, pseudo) VALUES (v, 'yr_' || n) ON CONFLICT DO NOTHING;
  RETURN v;
END $$;

-- A wish in the (only) wishlist of owner n, created at the given instant.
CREATE FUNCTION pg_temp.mk_wish(owner_n int, created timestamptz DEFAULT '2026-06-01T10:00:00Z', qty int DEFAULT 1)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE
  o uuid := pg_temp.u(owner_n);
  list_id bigint := 970000 + owner_n;
  wish_id bigint;
BEGIN
  INSERT INTO public.wishlists (id, name, id_owner, color, updated_by, visibility)
  VALUES (list_id, 'list ' || owner_n, o, '#FFFFFF', o, 'public')
  ON CONFLICT DO NOTHING;
  INSERT INTO public.wishs (name, description, quantity, wishlist_id, updated_by, created_at)
  VALUES ('wish', '', qty, list_id, o, created)
  RETURNING id INTO wish_id;
  RETURN wish_id;
END $$;

-- The owner marks a wish as received (completed_at a day, updated_at the instant).
CREATE FUNCTION pg_temp.receive(owner_n int, wish bigint, completed date, qty int DEFAULT 1, updated timestamptz DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.user_completed_wishs (user_id, wish_id, from_wishlist_id, quantity, completed_at, updated_at)
  SELECT pg_temp.u(owner_n), w.id, w.wishlist_id, qty, completed,
         COALESCE(updated, (completed + time '12:00') AT TIME ZONE 'Europe/Paris')
  FROM public.wishs w WHERE w.id = wish;
END $$;

CREATE FUNCTION pg_temp.book(booker_n int, wish bigint, created timestamptz DEFAULT '2026-02-10T10:00:00Z', qty int DEFAULT 1)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.wish_taken_by_user (wish_id, user_id, quantity, created_at)
  VALUES (wish, pg_temp.u(booker_n), qty, created);
END $$;

-- Offered wish: n books a wish of owner o, o marks it fully received at the instant.
CREATE FUNCTION pg_temp.offer(booker_n int, owner_n int, received_at timestamptz DEFAULT '2026-05-10T10:00:00Z')
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  w bigint := pg_temp.mk_wish(owner_n);
BEGIN
  PERFORM pg_temp.book(booker_n, w);
  PERFORM pg_temp.receive(owner_n, w, (received_at AT TIME ZONE 'Europe/Paris')::date, 1, received_at);
END $$;

-- N wishes received by the user on a day.
CREATE FUNCTION pg_temp.receive_many(owner_n int, how_many int, completed date)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  FOR i IN 1..how_many LOOP
    PERFORM pg_temp.receive(owner_n, pg_temp.mk_wish(owner_n, '2026-12-01T10:00:00Z'), completed);
  END LOOP;
END $$;

CREATE FUNCTION pg_temp.friend(a int, b int, st public.friendship_status, updated timestamptz)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.friendships (requester_id, receiver_id, status, created_at, updated_at)
  VALUES (pg_temp.u(a), pg_temp.u(b), st, updated, updated);
END $$;

-- Id of user n without creating it (usable after a change of role).
CREATE FUNCTION pg_temp.uid(n int) RETURNS uuid LANGUAGE sql AS $$
  SELECT ('00000000-0000-4000-d000-' || lpad(n::text, 12, '0'))::uuid;
$$;

CREATE FUNCTION pg_temp.st(n int) RETURNS jsonb LANGUAGE sql AS $$
  SELECT public.year_recap_stats(pg_temp.u(n), 2026);
$$;
CREATE FUNCTION pg_temp.pk(n int) RETURNS text LANGUAGE sql AS $$
  SELECT public.year_recap_pick_profile(pg_temp.st(n)) ->> 'key';
$$;
CREATE FUNCTION pg_temp.pick(stats text) RETURNS text LANGUAGE sql AS $$
  SELECT public.year_recap_pick_profile(stats::jsonb) ->> 'key';
$$;

-- 1. Seeds and table constraints
DO $$
BEGIN
  IF (SELECT count(*) FROM public.year_recap_profiles) <> 10 THEN
    RAISE EXCEPTION 'FAIL expected 10 seeded profiles';
  END IF;
  IF EXISTS (
    (SELECT key, threshold, weight, sort, enabled FROM public.year_recap_profiles
     EXCEPT
     SELECT * FROM (VALUES
       ('patient', 180, 1, 10, true), ('pere_noel_discret', 2, 1, 20, true),
       ('gate', 8, 1, 30, true), ('equilibriste', 2, 1, 40, true),
       ('reveur', 15, 1, 50, true), ('rassembleur', 5, 1, 60, true),
       ('ami_fidele', 3, 1, 70, true), ('dernier_moment', 0.5, 1, 80, true),
       ('organise', 3, 1, 90, true), ('minimaliste', 1, 1, 100, true)
     ) AS e(key, threshold, weight, sort, enabled))
  ) THEN
    RAISE EXCEPTION 'FAIL seeded profiles differ from the expected ones';
  END IF;
  RAISE NOTICE 'ok   10 profiles seeded with their thresholds';
END $$;

SELECT pg_temp.expect_sqlstate('threshold must be positive',
  $q$INSERT INTO public.year_recap_profiles (key, threshold, sort) VALUES ('t0', 0, 1)$q$, '23514');
SELECT pg_temp.expect_sqlstate('weight must be positive',
  $q$INSERT INTO public.year_recap_profiles (key, threshold, weight, sort) VALUES ('w0', 1, 0, 1)$q$, '23514');

-- 2. Scoring on crafted stats
SELECT pg_temp.expect_eq('no activity: minimaliste', pg_temp.pick('{}'), 'minimaliste');
SELECT pg_temp.expect_eq('score 0 for minimaliste',
  (public.year_recap_pick_profile('{}') ->> 'score'), '0');
SELECT pg_temp.expect_eq('pere noel: offered 3 > received 1',
  pg_temp.pick('{"received":1,"offered":3}'), 'pere_noel_discret');
SELECT pg_temp.expect_eq('pere noel needs offered > received',
  pg_temp.pick('{"received":2,"offered":2}'), 'equilibriste');
SELECT pg_temp.expect_eq('gap of 1: pere noel scores 1.5, equilibriste 1',
  pg_temp.pick('{"received":2,"offered":3}'), 'pere_noel_discret');
SELECT pg_temp.expect_eq('equilibriste: gap of 1, bigger stat',
  pg_temp.pick('{"received":4,"offered":3}'), 'equilibriste');
SELECT pg_temp.expect_eq('equilibriste: gap of 2 is not eligible',
  pg_temp.pick('{"received":5,"offered":3}'), 'minimaliste');
SELECT pg_temp.expect_eq('gate needs received >= 2 * offered',
  pg_temp.pick('{"received":8,"offered":4}'), 'gate');
SELECT pg_temp.expect_eq('gate: received 8 offered 5 is not eligible',
  pg_temp.pick('{"received":8,"offered":5}'), 'minimaliste');
SELECT pg_temp.expect_eq('dernier moment needs 2 last minute bookings',
  pg_temp.pick('{"last_minute_bookings":1,"last_minute_share":1,"bookings_total":1}'), 'minimaliste');
SELECT pg_temp.expect_eq('dernier moment with 2 bookings and a share of 0.5',
  pg_temp.pick('{"last_minute_bookings":2,"last_minute_share":0.5,"bookings_total":4}'), 'dernier_moment');
SELECT pg_temp.expect_eq('no longest awaited wish: null does not break the scoring',
  pg_temp.pick('{"longest_awaited":null,"wishes_added":15}'), 'reveur');
SELECT pg_temp.expect_eq('patient from the longest awaited wish',
  pg_temp.pick('{"received":1,"longest_awaited":{"days":180}}'), 'patient');

-- 3. Stats and profiles of seeded users (year 2026, Paris)

-- patient: wish created Jan 10 23:30 UTC = Jan 11 in Paris, received Jul 15 (185 days).
-- A longer wait received in 2025 and a shorter one in 2026 do not replace it.
DO $$
DECLARE
  w bigint := pg_temp.mk_wish(1, '2026-01-10T23:30:00Z');
BEGIN
  PERFORM pg_temp.receive(1, w, '2026-07-15');
  PERFORM pg_temp.receive(1, pg_temp.mk_wish(1, '2026-03-01T10:00:00Z'), '2026-07-20');
  PERFORM pg_temp.receive(1, pg_temp.mk_wish(1, '2024-01-01T10:00:00Z'), '2025-12-30');
  PERFORM pg_temp.expect_eq('patient: wait in days', pg_temp.st(1) #>> '{longest_awaited,days}', '185');
  PERFORM pg_temp.expect_eq('patient: wish id', pg_temp.st(1) #>> '{longest_awaited,wish_id}', w::text);
  PERFORM pg_temp.expect_eq('patient: creation day in Paris', pg_temp.st(1) #>> '{longest_awaited,created_on}', '2026-01-11');
  PERFORM pg_temp.expect_eq('patient: completed day', pg_temp.st(1) #>> '{longest_awaited,completed_on}', '2026-07-15');
  PERFORM pg_temp.expect_eq('patient: wish name', pg_temp.st(1) #>> '{longest_awaited,wish_name}', 'wish');
  PERFORM pg_temp.expect_eq('patient: received counts the 2026 rows only', pg_temp.st(1) ->> 'received', '2');
  PERFORM pg_temp.expect_eq('patient: profile', pg_temp.pk(1), 'patient');
END $$;

-- 178 days: under the threshold
DO $$
BEGIN
  PERFORM pg_temp.receive(2, pg_temp.mk_wish(2, '2026-01-10T23:30:00Z'), '2026-07-08');
  PERFORM pg_temp.expect_eq('178 days is not enough', pg_temp.pk(2), 'minimaliste');
  PERFORM pg_temp.expect_eq('no wish received: longest_awaited is null',
    (pg_temp.st(24) -> 'longest_awaited')::text, 'null');
END $$;

-- pere noel discret: 2 offered, 0 received
DO $$
BEGIN
  PERFORM pg_temp.offer(3, 90);
  PERFORM pg_temp.offer(3, 90);
  PERFORM pg_temp.expect_eq('offered 2', pg_temp.st(3) ->> 'offered', '2');
  PERFORM pg_temp.expect_eq('max offered to the same friend', pg_temp.st(3) ->> 'max_offered_same_friend', '2');
  PERFORM pg_temp.expect_eq('pere noel discret', pg_temp.pk(3), 'pere_noel_discret');
END $$;

-- a partial receipt is not offered (booked 2, received 1)
DO $$
DECLARE
  w bigint := pg_temp.mk_wish(91, '2026-06-01T10:00:00Z', 2);
BEGIN
  PERFORM pg_temp.book(4, w, '2026-02-10T10:00:00Z', 2);
  PERFORM pg_temp.receive(91, w, '2026-05-10', 1);
  PERFORM pg_temp.expect_eq('partial receipt: not offered', pg_temp.st(4) ->> 'offered', '0');
  PERFORM pg_temp.expect_eq('partial receipt: still a booking', pg_temp.st(4) ->> 'bookings_total', '1');
  -- the owner receives the second item: now offered
  UPDATE public.user_completed_wishs SET quantity = 2, updated_at = '2026-06-10T10:00:00Z'
    WHERE wish_id = w;
  PERFORM pg_temp.expect_eq('full receipt: offered', pg_temp.st(4) ->> 'offered', '1');
END $$;

-- offered at the year boundaries: receipt Dec 31 22:30 UTC (Paris Dec 31, 2025) no,
-- Dec 31 23:30 UTC (Paris Jan 1) yes, Dec 31 2026 23:30 UTC (Paris Jan 1, 2027) no
DO $$
BEGIN
  PERFORM pg_temp.offer(13, 90, '2025-12-31T22:30:00Z');
  PERFORM pg_temp.offer(13, 90, '2025-12-31T23:30:00Z');
  PERFORM pg_temp.offer(13, 90, '2026-12-31T23:30:00Z');
  PERFORM pg_temp.expect_eq('offered at the year boundaries', pg_temp.st(13) ->> 'offered', '1');
  PERFORM pg_temp.expect_eq('bookings of the year', pg_temp.st(13) ->> 'bookings_total', '3');
END $$;

-- the year of an offered gift is the day the owner received it (completed_at),
-- not the last change of the received quantity (updated_at): received Dec 28,
-- 2025 and corrected Jan 5, 2026 stays a 2025 gift; received Dec 30, 2026 and
-- corrected Jan 3, 2027 stays a 2026 gift
DO $$
DECLARE
  w1 bigint := pg_temp.mk_wish(90);
  w2 bigint := pg_temp.mk_wish(90);
BEGIN
  PERFORM pg_temp.book(32, w1);
  PERFORM pg_temp.book(32, w2);
  PERFORM pg_temp.receive(90, w1, '2025-12-28', 1, '2026-01-05T10:00:00Z');
  PERFORM pg_temp.receive(90, w2, '2026-12-30', 1, '2027-01-03T10:00:00Z');
  PERFORM pg_temp.expect_eq('offered: completed_at decides the year (2026)',
    pg_temp.st(32) ->> 'offered', '1');
  PERFORM pg_temp.expect_eq('offered: completed_at decides the year (2025)',
    public.year_recap_stats(pg_temp.u(32), 2025) ->> 'offered', '1');
  PERFORM pg_temp.expect_eq('ami fidele: completed_at decides the year',
    public.year_recap_stats(pg_temp.u(32), 2025) ->> 'max_offered_same_friend', '1');
END $$;

-- a friend archiving their wishlist after the gifts does not drop them
DO $$
BEGIN
  PERFORM pg_temp.offer(26, 96);
  UPDATE public.wishlists SET deleted_at = '2026-08-01T10:00:00Z' WHERE id = 970096;
  PERFORM pg_temp.expect_eq('archived wishlist: still offered', pg_temp.st(26) ->> 'offered', '1');
  PERFORM pg_temp.expect_eq('archived wishlist: still a booking', pg_temp.st(26) ->> 'bookings_total', '1');
  PERFORM pg_temp.expect_eq('archived wishlist: still counts for ami fidele', pg_temp.st(26) ->> 'max_offered_same_friend', '1');
  -- a wishlist that no longer exists is gone with its wishes and bookings
  PERFORM pg_temp.offer(26, 99);
  DELETE FROM public.wishlists WHERE id = 970099;
  PERFORM pg_temp.expect_eq('deleted wishlist: not offered', pg_temp.st(26) ->> 'offered', '1');
  PERFORM pg_temp.expect_eq('deleted wishlist: not a booking', pg_temp.st(26) ->> 'bookings_total', '1');
END $$;

-- a booking on an archived wishlist still counts as last minute (Christmas)
DO $$
BEGIN
  PERFORM pg_temp.book(30, pg_temp.mk_wish(86), '2026-12-24T12:00:00Z');
  PERFORM pg_temp.book(30, pg_temp.mk_wish(86), '2026-12-23T12:00:00Z');
  UPDATE public.wishlists SET deleted_at = '2026-12-30T10:00:00Z' WHERE id = 970086;
  PERFORM pg_temp.expect_eq('archived wishlist: last minute bookings', pg_temp.st(30) ->> 'last_minute_bookings', '2');
END $$;

-- a receipt row of someone else than the owner does not make a booking offered
DO $$
DECLARE
  w bigint := pg_temp.mk_wish(97);
BEGIN
  PERFORM pg_temp.book(27, w);
  PERFORM pg_temp.receive(98, w, '2026-05-10');
  PERFORM pg_temp.expect_eq('receipt of another user: not offered', pg_temp.st(27) ->> 'offered', '0');
END $$;

-- equilibriste: offered 2, received 2
DO $$
BEGIN
  PERFORM pg_temp.offer(5, 90);
  PERFORM pg_temp.offer(5, 91);
  PERFORM pg_temp.receive_many(5, 2, '2026-07-01');
  PERFORM pg_temp.expect_eq('equilibriste', pg_temp.pk(5), 'equilibriste');
END $$;

-- longest awaited is the longest wait, not the oldest wish:
-- A created 2025-01-01 received 2026-01-02 (366 days), B created 2025-01-02
-- received 2026-12-30 (727 days): B
DO $$
DECLARE
  b bigint := pg_temp.mk_wish(31, '2025-01-02T10:00:00Z');
BEGIN
  PERFORM pg_temp.receive(31, pg_temp.mk_wish(31, '2025-01-01T10:00:00Z'), '2026-01-02');
  PERFORM pg_temp.receive(31, b, '2026-12-30');
  PERFORM pg_temp.expect_eq('longest awaited: wish', pg_temp.st(31) #>> '{longest_awaited,wish_id}', b::text);
  PERFORM pg_temp.expect_eq('longest awaited: days', pg_temp.st(31) #>> '{longest_awaited,days}', '727');
END $$;

-- offered 3 received 1: pere noel (gap 2, not an equilibriste)
DO $$
BEGIN
  PERFORM pg_temp.offer(14, 90);
  PERFORM pg_temp.offer(14, 91);
  PERFORM pg_temp.offer(14, 92);
  PERFORM pg_temp.receive_many(14, 1, '2026-07-01');
  PERFORM pg_temp.expect_eq('pere noel with a gap of 2', pg_temp.pk(14), 'pere_noel_discret');
END $$;

-- gate: received 8, offered 4 (boundary 2x); received 8, offered 5: not eligible
DO $$
BEGIN
  PERFORM pg_temp.receive_many(16, 8, '2026-07-01');
  FOR i IN 1..4 LOOP PERFORM pg_temp.offer(16, 90 + i); END LOOP;
  PERFORM pg_temp.expect_eq('gate', pg_temp.pk(16), 'gate');
  PERFORM pg_temp.receive_many(15, 8, '2026-07-01');
  FOR i IN 1..5 LOOP PERFORM pg_temp.offer(15, 90 + i); END LOOP;
  PERFORM pg_temp.expect_eq('gate not eligible at received 8 offered 5', pg_temp.pk(15), 'minimaliste');
END $$;

-- reveur: 15 wishes added
DO $$
BEGIN
  FOR i IN 1..15 LOOP PERFORM pg_temp.mk_wish(7, '2026-03-01T10:00:00Z'); END LOOP;
  PERFORM pg_temp.expect_eq('wishes added', pg_temp.st(7) ->> 'wishes_added', '15');
  PERFORM pg_temp.expect_eq('reveur', pg_temp.pk(7), 'reveur');
END $$;

-- 13 wishes + Dec 31 23:30 UTC 2025 (Paris Jan 1, counts) + Dec 31 23:30 UTC 2026 (Paris 2027, no)
DO $$
BEGIN
  FOR i IN 1..13 LOOP PERFORM pg_temp.mk_wish(17, '2026-03-01T10:00:00Z'); END LOOP;
  PERFORM pg_temp.mk_wish(17, '2025-12-31T23:30:00Z');
  PERFORM pg_temp.mk_wish(17, '2026-12-31T23:30:00Z');
  PERFORM pg_temp.expect_eq('wishes added at the year boundaries', pg_temp.st(17) ->> 'wishes_added', '14');
  PERFORM pg_temp.expect_eq('14 wishes: no reveur', pg_temp.pk(17), 'minimaliste');
END $$;

-- rassembleur: 5 accepted friendships in the year (requester or receiver),
-- not the pending one, the one of 2025 (Dec 31 22:30 UTC) or of 2027 (Paris)
DO $$
BEGIN
  PERFORM pg_temp.friend(8, 100, 'accepted', '2026-03-01T10:00:00Z');
  PERFORM pg_temp.friend(8, 101, 'accepted', '2026-04-01T10:00:00Z');
  PERFORM pg_temp.friend(102, 8, 'accepted', '2026-05-01T10:00:00Z');
  PERFORM pg_temp.friend(103, 8, 'accepted', '2026-06-01T10:00:00Z');
  PERFORM pg_temp.friend(8, 107, 'accepted', '2025-12-31T23:30:00Z');
  PERFORM pg_temp.friend(8, 105, 'pending', '2026-06-01T10:00:00Z');
  PERFORM pg_temp.friend(8, 106, 'accepted', '2025-12-31T22:30:00Z');
  PERFORM pg_temp.friend(8, 108, 'accepted', '2026-12-31T23:30:00Z');
  PERFORM pg_temp.expect_eq('new friends', pg_temp.st(8) ->> 'new_friends', '5');
  PERFORM pg_temp.expect_eq('rassembleur', pg_temp.pk(8), 'rassembleur');
END $$;

-- ami fidele: 3 offered to the same friend, 5 received (not a pere noel, not a gate)
DO $$
BEGIN
  FOR i IN 1..3 LOOP PERFORM pg_temp.offer(9, 91); END LOOP;
  PERFORM pg_temp.receive_many(9, 5, '2026-07-01');
  PERFORM pg_temp.expect_eq('ami fidele: max offered to a friend', pg_temp.st(9) ->> 'max_offered_same_friend', '3');
  PERFORM pg_temp.expect_eq('ami fidele', pg_temp.pk(9), 'ami_fidele');
END $$;

-- dernier moment, Christmas: Dec 23, 22 (3 days, inclusive), 25 (0 days) count; Dec 21 (4) and 26 do not
DO $$
BEGIN
  PERFORM pg_temp.book(10, pg_temp.mk_wish(92), '2026-12-23T12:00:00Z');
  PERFORM pg_temp.book(10, pg_temp.mk_wish(92), '2026-12-22T12:00:00Z');
  PERFORM pg_temp.book(10, pg_temp.mk_wish(92), '2026-12-21T12:00:00Z');
  PERFORM pg_temp.book(10, pg_temp.mk_wish(92), '2026-12-25T12:00:00Z');
  PERFORM pg_temp.book(10, pg_temp.mk_wish(92), '2026-12-26T12:00:00Z');
  PERFORM pg_temp.expect_eq('last minute bookings (Christmas)', pg_temp.st(10) ->> 'last_minute_bookings', '3');
  PERFORM pg_temp.expect_eq('bookings total', pg_temp.st(10) ->> 'bookings_total', '5');
  PERFORM pg_temp.expect_eq('last minute share', pg_temp.st(10) ->> 'last_minute_share', '0.6000');
  PERFORM pg_temp.expect_eq('dernier moment', pg_temp.pk(10), 'dernier_moment');
END $$;

-- dernier moment, birthday of the owner (Mar 10): Mar 8 and Mar 7 count, Mar 6 does not
DO $$
BEGIN
  PERFORM pg_temp.friend(18, 93, 'accepted', '2026-01-05T10:00:00Z');
  INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES (pg_temp.u(93), 3, 10);
  PERFORM pg_temp.book(18, pg_temp.mk_wish(93), '2026-03-08T12:00:00Z');
  PERFORM pg_temp.book(18, pg_temp.mk_wish(93), '2026-03-07T12:00:00Z');
  PERFORM pg_temp.book(18, pg_temp.mk_wish(93), '2026-03-06T12:00:00Z');
  PERFORM pg_temp.expect_eq('last minute bookings (owner birthday)', pg_temp.st(18) ->> 'last_minute_bookings', '2');
  PERFORM pg_temp.expect_eq('dernier moment (birthday)', pg_temp.pk(18), 'dernier_moment');
END $$;

-- birthday on Jan 2: bookings of Dec 30 and 31 are within 3 days of the next birthday
DO $$
BEGIN
  PERFORM pg_temp.friend(19, 94, 'accepted', '2026-01-05T10:00:00Z');
  INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES (pg_temp.u(94), 1, 2);
  PERFORM pg_temp.book(19, pg_temp.mk_wish(94), '2026-12-30T12:00:00Z');
  PERFORM pg_temp.book(19, pg_temp.mk_wish(94), '2026-12-31T12:00:00Z');
  PERFORM pg_temp.expect_eq('birthday in January, booked in December', pg_temp.st(19) ->> 'last_minute_bookings', '2');
END $$;

-- Feb 29 birthday is Feb 28 in 2026: Feb 27 and 26 count, Mar 1 does not
DO $$
BEGIN
  PERFORM pg_temp.friend(20, 95, 'accepted', '2026-01-05T10:00:00Z');
  INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES (pg_temp.u(95), 2, 29);
  PERFORM pg_temp.book(20, pg_temp.mk_wish(95), '2026-02-27T12:00:00Z');
  PERFORM pg_temp.book(20, pg_temp.mk_wish(95), '2026-02-26T12:00:00Z');
  PERFORM pg_temp.book(20, pg_temp.mk_wish(95), '2026-03-01T12:00:00Z');
  PERFORM pg_temp.expect_eq('Feb 29 birthday in a common year', pg_temp.st(20) ->> 'last_minute_bookings', '2');
END $$;

-- the birthday of a non-friend is not used (it would leak through the stat:
-- book, move created_at, bisect). Pending and blocked do not count either.
-- Owners 84 (stranger), 83 (pending), 82 (blocked) have a birthday on Mar 10;
-- Christmas still counts for everybody.
DO $$
BEGIN
  INSERT INTO public.profile_birthdays (profile_id, month, day)
  VALUES (pg_temp.u(84), 3, 10), (pg_temp.u(83), 3, 10), (pg_temp.u(82), 3, 10);
  PERFORM pg_temp.friend(28, 83, 'pending', '2026-01-05T10:00:00Z');
  PERFORM pg_temp.friend(28, 82, 'blocked', '2026-01-05T10:00:00Z');
  PERFORM pg_temp.book(28, pg_temp.mk_wish(84), '2026-03-08T12:00:00Z');
  PERFORM pg_temp.book(28, pg_temp.mk_wish(83), '2026-03-09T12:00:00Z');
  PERFORM pg_temp.book(28, pg_temp.mk_wish(82), '2026-03-10T12:00:00Z');
  PERFORM pg_temp.expect_eq('non-friend birthday is ignored', pg_temp.st(28) ->> 'last_minute_bookings', '0');
  PERFORM pg_temp.book(28, pg_temp.mk_wish(84), '2026-12-24T12:00:00Z');
  PERFORM pg_temp.expect_eq('non-friend: Christmas still counts', pg_temp.st(28) ->> 'last_minute_bookings', '1');
END $$;

-- booking boundaries: Dec 31 2025 23:30 UTC is Jan 1 2026 (counts), Dec 31 2026 23:30 UTC is 2027
DO $$
BEGIN
  PERFORM pg_temp.book(21, pg_temp.mk_wish(92), '2025-12-31T23:30:00Z');
  PERFORM pg_temp.book(21, pg_temp.mk_wish(92), '2026-12-31T23:30:00Z');
  PERFORM pg_temp.expect_eq('bookings at the year boundaries', pg_temp.st(21) ->> 'bookings_total', '1');
END $$;

-- one last minute booking only: not eligible although the share is 1
DO $$
BEGIN
  PERFORM pg_temp.book(22, pg_temp.mk_wish(92), '2026-12-24T12:00:00Z');
  PERFORM pg_temp.expect_eq('one last minute booking: share', pg_temp.st(22) ->> 'last_minute_share', '1.0000');
  PERFORM pg_temp.expect_eq('one last minute booking: not eligible', pg_temp.pk(22), 'minimaliste');
END $$;

-- organise: 3 wishes received on Dec 25
DO $$
BEGIN
  PERFORM pg_temp.receive_many(11, 3, '2026-12-25');
  PERFORM pg_temp.expect_eq('received on party day (Christmas)', pg_temp.st(11) ->> 'received_on_party_day', '3');
  PERFORM pg_temp.expect_eq('organise (Christmas)', pg_temp.pk(11), 'organise');
END $$;

-- organise, own birthday (Jun 5): 2 on Jun 5, 1 on Dec 25, 1 on Jun 6
DO $$
BEGIN
  INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES (pg_temp.u(12), 6, 5);
  PERFORM pg_temp.receive_many(12, 2, '2026-06-05');
  PERFORM pg_temp.receive_many(12, 1, '2026-12-25');
  PERFORM pg_temp.receive_many(12, 1, '2026-06-06');
  PERFORM pg_temp.expect_eq('received on party day (own birthday)', pg_temp.st(12) ->> 'received_on_party_day', '3');
  PERFORM pg_temp.expect_eq('organise (own birthday)', pg_temp.pk(12), 'organise');
END $$;

-- own birthday on Feb 29: the day is Feb 28 in 2026
DO $$
BEGIN
  INSERT INTO public.profile_birthdays (profile_id, month, day) VALUES (pg_temp.u(23), 2, 29);
  PERFORM pg_temp.receive_many(23, 1, '2026-02-28');
  PERFORM pg_temp.expect_eq('Feb 29 own birthday', pg_temp.st(23) ->> 'received_on_party_day', '1');
END $$;

-- minimaliste: no activity at all
SELECT pg_temp.expect_eq('minimaliste', pg_temp.pk(24), 'minimaliste');

-- 4. Ties and settings: 15 wishes (reveur = 1) and 5 friends (rassembleur = 1)
DO $$
BEGIN
  FOR i IN 1..15 LOOP PERFORM pg_temp.mk_wish(25, '2026-03-01T10:00:00Z'); END LOOP;
  PERFORM pg_temp.friend(25, 100, 'accepted', '2026-03-01T10:00:00Z');
  PERFORM pg_temp.friend(25, 101, 'accepted', '2026-03-01T10:00:00Z');
  PERFORM pg_temp.friend(25, 102, 'accepted', '2026-03-01T10:00:00Z');
  PERFORM pg_temp.friend(25, 103, 'accepted', '2026-03-01T10:00:00Z');
  PERFORM pg_temp.friend(25, 104, 'accepted', '2026-03-01T10:00:00Z');
  PERFORM pg_temp.expect_eq('tie: the smaller sort wins', pg_temp.pk(25), 'reveur');
  UPDATE public.year_recap_profiles SET sort = 5 WHERE key = 'rassembleur';
  PERFORM pg_temp.expect_eq('tie: sort changed', pg_temp.pk(25), 'rassembleur');
  UPDATE public.year_recap_profiles SET sort = 60 WHERE key = 'rassembleur';
  UPDATE public.year_recap_profiles SET weight = 2 WHERE key = 'rassembleur';
  PERFORM pg_temp.expect_eq('weight 2 beats the tie', pg_temp.pk(25), 'rassembleur');
  PERFORM pg_temp.expect_eq('score = stat * weight / threshold',
    public.year_recap_pick_profile(pg_temp.st(25)) ->> 'score', '2.0000');
  UPDATE public.year_recap_profiles SET weight = 1, enabled = false WHERE key = 'rassembleur';
  PERFORM pg_temp.expect_eq('a disabled profile is never chosen', pg_temp.pk(25), 'reveur');
  UPDATE public.year_recap_profiles SET enabled = true, threshold = 30 WHERE key = 'reveur';
  UPDATE public.year_recap_profiles SET enabled = true WHERE key = 'rassembleur';
  PERFORM pg_temp.expect_eq('threshold 30: reveur scores 0.5', pg_temp.pk(25), 'rassembleur');
  UPDATE public.year_recap_profiles SET threshold = 15 WHERE key = 'reveur';
  UPDATE public.year_recap_profiles SET enabled = false;
  PERFORM pg_temp.expect_eq('every profile disabled: minimaliste', pg_temp.pk(25), 'minimaliste');
  UPDATE public.year_recap_profiles SET enabled = true;
  -- stat * weight / threshold: 1 * 3 / 3 is exactly 1 (1 / 3 * 3 would give 0.999...)
  UPDATE public.year_recap_profiles SET threshold = 3, weight = 3 WHERE key = 'reveur';
  PERFORM pg_temp.expect_eq('score rounding: stat 1, threshold 3, weight 3',
    pg_temp.pick('{"wishes_added":1}'), 'reveur');
  UPDATE public.year_recap_profiles SET threshold = 15, weight = 1 WHERE key = 'reveur';
END $$;

-- 5. Illustration column and bucket
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'year_recap_profiles'
      AND column_name = 'illustration_path' AND data_type = 'text' AND is_nullable = 'YES'
  ) THEN
    RAISE EXCEPTION 'FAIL illustration_path column missing or not nullable text';
  END IF;
  IF EXISTS (SELECT 1 FROM public.year_recap_profiles WHERE illustration_path IS NOT NULL) THEN
    RAISE EXCEPTION 'FAIL illustration_path must be seeded with null';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'year-recap-illustrations') THEN
    RAISE EXCEPTION 'FAIL bucket year-recap-illustrations missing';
  END IF;
  IF (
    SELECT count(*) FROM information_schema.columns
    WHERE table_schema = 'storage' AND table_name = 'buckets'
      AND column_name IN ('public', 'file_size_limit', 'allowed_mime_types')
  ) = 3 THEN
    IF NOT EXISTS (
      SELECT 1 FROM storage.buckets b
      WHERE b.id = 'year-recap-illustrations' AND to_jsonb(b) @> '{"public": true}'
    ) THEN
      RAISE EXCEPTION 'FAIL year-recap-illustrations is not public';
    END IF;
  END IF;
  RAISE NOTICE 'ok   illustration_path column and bucket';
END $$;
UPDATE public.year_recap_profiles SET illustration_path = 'patient.webp' WHERE key = 'patient';

-- 6. Public RPC, grants and RLS
SELECT pg_temp.act_as(pg_temp.uid(1));
DO $$
DECLARE
  r jsonb;
BEGIN
  r := public.get_my_year_recap(2026);
  PERFORM pg_temp.expect_eq('rpc: year', r ->> 'year', '2026');
  PERFORM pg_temp.expect_eq('rpc: profile key', r #>> '{profile,key}', 'patient');
  PERFORM pg_temp.expect_eq('rpc: illustration path', r #>> '{profile,illustration_path}', 'patient.webp');
  PERFORM pg_temp.expect_eq('rpc: stats received', r #>> '{stats,received}', '2');
  PERFORM pg_temp.expect_eq('rpc: stats keys',
    (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(r -> 'stats') k),
    'bookings_total,last_minute_bookings,last_minute_share,longest_awaited,max_offered_same_friend,new_friends,offered,received,received_on_party_day,wishes_added');
  PERFORM pg_temp.expect_eq('rpc: profile keys',
    (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(r -> 'profile') k),
    'illustration_path,key,score');
END $$;
-- a profile with no illustration: the key is present, null
SELECT pg_temp.act_as(pg_temp.uid(24));
SELECT pg_temp.expect_eq('rpc: null illustration path is explicit null',
  (public.get_my_year_recap(2026) #> '{profile,illustration_path}')::text, 'null');
SELECT pg_temp.expect_eq('rpc: default year is the current Paris year',
  public.get_my_year_recap() ->> 'year', extract(year FROM public.paris_today())::text);

SELECT pg_temp.act_as(pg_temp.uid(1));
SELECT pg_temp.expect_denied('authenticated cannot call year_recap_stats',
  $q$SELECT public.year_recap_stats(auth.uid(), 2026)$q$);
SELECT pg_temp.expect_denied('authenticated cannot call year_recap_pick_profile',
  $q$SELECT public.year_recap_pick_profile('{}'::jsonb)$q$);
SELECT pg_temp.expect_denied('authenticated cannot call year_recap_birthday_in',
  $q$SELECT public.year_recap_birthday_in(2, 29, 2026)$q$);
SELECT pg_temp.expect_denied('authenticated cannot insert profiles',
  $q$INSERT INTO public.year_recap_profiles (key, threshold, sort) VALUES ('x', 1, 1)$q$);
SELECT pg_temp.expect_denied('authenticated cannot update profiles',
  $q$UPDATE public.year_recap_profiles SET threshold = 1$q$);
SELECT pg_temp.expect_denied('authenticated cannot delete profiles',
  $q$DELETE FROM public.year_recap_profiles$q$);
SELECT pg_temp.expect_denied('authenticated cannot upload to the illustrations bucket',
  $q$INSERT INTO storage.objects (bucket_id, name) VALUES ('year-recap-illustrations', 'x.webp')$q$);
DO $$
BEGIN
  IF (SELECT count(*) FROM public.year_recap_profiles) <> 10 THEN
    RAISE EXCEPTION 'FAIL authenticated must read the 10 profiles';
  END IF;
  RAISE NOTICE 'ok   authenticated reads the profiles';
END $$;

SELECT pg_temp.act_as(NULL);
SELECT pg_temp.expect_sqlstate('no user id: error', $q$SELECT public.get_my_year_recap(2026)$q$, '28000');

SELECT pg_temp.act_as_anon();
SELECT pg_temp.expect_denied('anon cannot call get_my_year_recap', $q$SELECT public.get_my_year_recap(2026)$q$);
SELECT pg_temp.expect_denied('anon cannot call year_recap_stats',
  $q$SELECT public.year_recap_stats('00000000-0000-4000-d000-000000000001', 2026)$q$);
SELECT pg_temp.expect_denied('anon cannot read profiles', $q$SELECT * FROM public.year_recap_profiles$q$);

RESET ROLE;

-- 7. Invalid arguments
SELECT pg_temp.expect_sqlstate('year out of range',
  $q$SELECT public.year_recap_stats('00000000-0000-4000-d000-000000000001', 1999)$q$, '22023');

ROLLBACK;
