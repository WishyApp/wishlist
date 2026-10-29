-- Rules of user_card_states (20261030100001_user_card_states).
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

CREATE FUNCTION pg_temp.act_as(user_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', user_id::text, true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
END $$;

CREATE FUNCTION pg_temp.act_as_anon()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
END $$;

CREATE FUNCTION pg_temp.expect_true(label text, condition boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS NOT TRUE THEN
    RAISE EXCEPTION 'FAIL %', label;
  END IF;
  RAISE NOTICE 'ok   %', label;
END $$;

-- Fixtures: two users.
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-e000-00000000000a'),
  ('00000000-0000-4000-e000-00000000000b');
INSERT INTO public.profiles (id, pseudo) VALUES
  ('00000000-0000-4000-e000-00000000000a', 'cards_a'),
  ('00000000-0000-4000-e000-00000000000b', 'cards_b');

-- As A
SELECT pg_temp.act_as('00000000-0000-4000-e000-00000000000a');
SELECT public.record_card_shown('booked_reminder:1');
SELECT public.record_card_shown('booked_reminder:1');
SELECT pg_temp.expect_true('two displays are counted',
  (SELECT shown_count = 2 AND last_shown_at IS NOT NULL
   FROM public.user_card_states WHERE card_key = 'booked_reminder:1'));

SELECT public.dismiss_card('booked_reminder:1');
SELECT pg_temp.expect_true('dismiss without snooze keeps the count',
  (SELECT dismissed_at IS NOT NULL AND snoozed_until IS NULL AND shown_count = 2
   FROM public.user_card_states WHERE card_key = 'booked_reminder:1'));

SELECT public.dismiss_card('stale_wishlist:9', now() + interval '180 days');
SELECT pg_temp.expect_true('dismiss with snooze creates the row with the date',
  (SELECT dismissed_at IS NOT NULL
      AND snoozed_until BETWEEN now() + interval '179 days' AND now() + interval '181 days'
      AND shown_count = 0
   FROM public.user_card_states WHERE card_key = 'stale_wishlist:9'));
SELECT pg_temp.expect_rows('A reads own rows',
  $q$SELECT * FROM public.user_card_states$q$, 2);

SELECT pg_temp.expect_denied('direct INSERT',
  $q$INSERT INTO public.user_card_states (user_id, card_key) VALUES ('00000000-0000-4000-e000-00000000000a', 'x:1')$q$);
SELECT pg_temp.expect_denied('direct UPDATE',
  $q$UPDATE public.user_card_states SET shown_count = 99$q$);
SELECT pg_temp.expect_denied('direct DELETE',
  $q$DELETE FROM public.user_card_states$q$);
RESET ROLE;

-- As B
SELECT pg_temp.act_as('00000000-0000-4000-e000-00000000000b');
SELECT pg_temp.expect_rows('B sees no row of A',
  $q$SELECT * FROM public.user_card_states$q$, 0);
SELECT public.dismiss_card('booked_reminder:1');
SELECT pg_temp.expect_rows('B has its own row',
  $q$SELECT * FROM public.user_card_states WHERE card_key = 'booked_reminder:1'$q$, 1);
RESET ROLE;
SELECT pg_temp.expect_true('row of A untouched by B',
  (SELECT shown_count = 2 FROM public.user_card_states
   WHERE user_id = '00000000-0000-4000-e000-00000000000a' AND card_key = 'booked_reminder:1'));

-- anon
SELECT pg_temp.act_as_anon();
SELECT pg_temp.expect_denied('anon record_card_shown',
  $q$SELECT public.record_card_shown('booked_reminder:1')$q$);
SELECT pg_temp.expect_denied('anon dismiss_card',
  $q$SELECT public.dismiss_card('booked_reminder:1')$q$);
SELECT pg_temp.expect_denied('anon reads the table',
  $q$SELECT * FROM public.user_card_states$q$);
RESET ROLE;

-- Deleting the user deletes their rows
DELETE FROM auth.users WHERE id = '00000000-0000-4000-e000-00000000000a';
SELECT pg_temp.expect_true('rows go with the user',
  NOT EXISTS (SELECT 1 FROM public.user_card_states
              WHERE user_id = '00000000-0000-4000-e000-00000000000a'));

ROLLBACK;
