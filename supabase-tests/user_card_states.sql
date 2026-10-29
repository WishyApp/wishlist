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
EXCEPTION WHEN insufficient_privilege OR check_violation OR not_null_violation OR invalid_parameter_value THEN
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

-- As B, same key as A
SELECT pg_temp.act_as('00000000-0000-4000-e000-00000000000b');
SELECT pg_temp.expect_rows('B sees no row of A',
  $q$SELECT * FROM public.user_card_states$q$, 0);
SELECT public.record_card_shown('booked_reminder:1');
SELECT public.dismiss_card('booked_reminder:1', now() + interval '3 days');
SELECT pg_temp.expect_rows('B has its own row',
  $q$SELECT * FROM public.user_card_states WHERE card_key = 'booked_reminder:1'$q$, 1);
RESET ROLE;
SELECT pg_temp.expect_true('row of A untouched by B',
  (SELECT shown_count = 2 AND snoozed_until IS NULL
   FROM public.user_card_states
   WHERE user_id = '00000000-0000-4000-e000-00000000000a' AND card_key = 'booked_reminder:1'));
SELECT pg_temp.expect_true('row of B has its own count and snooze',
  (SELECT shown_count = 1 AND snoozed_until BETWEEN now() + interval '2 days 23 hours' AND now() + interval '3 days 1 hour'
   FROM public.user_card_states
   WHERE user_id = '00000000-0000-4000-e000-00000000000b' AND card_key = 'booked_reminder:1'));

-- Semantics the app relies on. now() is constant in the transaction: push the
-- timestamps to the past first so that a refresh is visible.
UPDATE public.user_card_states SET dismissed_at = '2000-01-01', last_shown_at = '2000-01-01'
  WHERE user_id = '00000000-0000-4000-e000-00000000000a' AND card_key = 'booked_reminder:1';
SELECT pg_temp.act_as('00000000-0000-4000-e000-00000000000a');
SELECT public.dismiss_card('booked_reminder:1', now() + interval '1 day');
SELECT public.dismiss_card('booked_reminder:1');
SELECT pg_temp.expect_true('dismiss after a snooze clears the snooze and refreshes dismissed_at',
  (SELECT snoozed_until IS NULL AND dismissed_at > '2000-01-01'
   FROM public.user_card_states WHERE card_key = 'booked_reminder:1'));

RESET ROLE;
UPDATE public.user_card_states SET dismissed_at = '2000-01-01', last_shown_at = '2000-01-01',
    snoozed_until = now() + interval '5 days', shown_count = 2
  WHERE user_id = '00000000-0000-4000-e000-00000000000a' AND card_key = 'booked_reminder:1';
SELECT pg_temp.act_as('00000000-0000-4000-e000-00000000000a');
SELECT public.record_card_shown('booked_reminder:1');
SELECT pg_temp.expect_true('record_card_shown leaves dismissal and snooze alone',
  (SELECT dismissed_at = '2000-01-01' AND snoozed_until > now() + interval '4 days'
      AND shown_count = 3 AND last_shown_at > '2000-01-01'
   FROM public.user_card_states WHERE card_key = 'booked_reminder:1'));

RESET ROLE;
UPDATE public.user_card_states SET snoozed_until = now() - interval '1 day'
  WHERE user_id = '00000000-0000-4000-e000-00000000000a' AND card_key = 'booked_reminder:1';
SELECT pg_temp.act_as('00000000-0000-4000-e000-00000000000a');
SELECT public.dismiss_card('booked_reminder:1', now() + interval '7 days');
SELECT pg_temp.expect_true('dismiss after an expired snooze sets the new date',
  (SELECT snoozed_until > now() + interval '6 days'
   FROM public.user_card_states WHERE card_key = 'booked_reminder:1'));

-- A permanent mask stays permanent: a late "later" cannot turn it into a snooze
SELECT public.dismiss_card('permanent:1');
SELECT public.dismiss_card('permanent:1', now() + interval '1 day');
SELECT pg_temp.expect_true('snooze after a permanent mask keeps it permanent',
  (SELECT dismissed_at IS NOT NULL AND snoozed_until IS NULL
   FROM public.user_card_states WHERE card_key = 'permanent:1'));

-- A mask is never shortened: a late "later" cannot bring a hidden card back sooner
SELECT public.dismiss_card('long_mask:1', now() + interval '60 days');
SELECT public.dismiss_card('long_mask:1', now() + interval '1 day');
SELECT pg_temp.expect_true('a shorter snooze does not shorten the mask',
  (SELECT snoozed_until > now() + interval '59 days'
   FROM public.user_card_states WHERE card_key = 'long_mask:1'));
SELECT public.dismiss_card('long_mask:1', now() + interval '90 days');
SELECT pg_temp.expect_true('a longer snooze extends the mask',
  (SELECT snoozed_until > now() + interval '89 days'
   FROM public.user_card_states WHERE card_key = 'long_mask:1'));

-- Non-finite dates are refused, a past date is accepted
SELECT pg_temp.expect_denied('infinite snooze',
  $q$SELECT public.dismiss_card('infinite:1', 'infinity'::timestamptz)$q$);
SELECT pg_temp.expect_denied('-infinite snooze',
  $q$SELECT public.dismiss_card('infinite:2', '-infinity'::timestamptz)$q$);
SELECT public.dismiss_card('past:1', now() - interval '1 day');
SELECT pg_temp.expect_true('past snooze is accepted',
  (SELECT snoozed_until < now() FROM public.user_card_states WHERE card_key = 'past:1'));

-- Key length: 1 to 200 characters
SELECT pg_temp.expect_denied('key of 201 characters',
  $q$SELECT public.record_card_shown(repeat('a', 201))$q$);
SELECT pg_temp.expect_denied('empty key',
  $q$SELECT public.record_card_shown('')$q$);
SELECT pg_temp.expect_denied('empty key on dismiss',
  $q$SELECT public.dismiss_card('')$q$);
RESET ROLE;

-- Signatures: no user id parameter, one function of each name
SELECT pg_temp.expect_true('function signatures are pinned',
  to_regprocedure('public.dismiss_card(text, timestamptz)') IS NOT NULL
  AND to_regprocedure('public.record_card_shown(text)') IS NOT NULL
  AND (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'dismiss_card') = 1
  AND (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'record_card_shown') = 1);

-- anon
SELECT pg_temp.act_as_anon();
SELECT pg_temp.expect_denied('anon record_card_shown',
  $q$SELECT public.record_card_shown('booked_reminder:1')$q$);
SELECT pg_temp.expect_denied('anon dismiss_card',
  $q$SELECT public.dismiss_card('booked_reminder:1')$q$);
SELECT pg_temp.expect_denied('anon reads the table',
  $q$SELECT * FROM public.user_card_states$q$);
RESET ROLE;

-- Yearly purge. User C owns rows of every age.
INSERT INTO auth.users (id) VALUES ('00000000-0000-4000-e000-00000000000c');
INSERT INTO public.profiles (id, pseudo) VALUES ('00000000-0000-4000-e000-00000000000c', 'cards_c');
INSERT INTO public.user_card_states (user_id, card_key, shown_count, last_shown_at, dismissed_at, snoozed_until) VALUES
  -- purged: nothing for more than a year, and no snooze left
  ('00000000-0000-4000-e000-00000000000c', 'old_shown:1', 1, now() - interval '13 months', NULL, NULL),
  ('00000000-0000-4000-e000-00000000000c', 'old_dismissed:1', 1, now() - interval '14 months', now() - interval '13 months', NULL),
  ('00000000-0000-4000-e000-00000000000c', 'old_permanent:1', 0, NULL, now() - interval '2 years', NULL),
  ('00000000-0000-4000-e000-00000000000c', 'old_expired:1', 0, NULL, now() - interval '2 years', now() - interval '18 months'),
  -- kept
  ('00000000-0000-4000-e000-00000000000c', 'recent:1', 1, now() - interval '11 months', NULL, NULL),
  ('00000000-0000-4000-e000-00000000000c', 'recent_dismissed:1', 1, now() - interval '2 years', now() - interval '11 months', NULL),
  ('00000000-0000-4000-e000-00000000000c', 'old_snoozed:1', 0, NULL, now() - interval '2 years', now() + interval '1 month'),
  ('00000000-0000-4000-e000-00000000000c', 'onboarding:birthday', 0, NULL, now() - interval '5 years', NULL),
  ('00000000-0000-4000-e000-00000000000c', 'onboarding:photo', 0, NULL, now() - interval '5 years', NULL),
  ('00000000-0000-4000-e000-00000000000c', 'onboarding:optional_window', 1, now() - interval '5 years', NULL, NULL);

SELECT pg_temp.act_as('00000000-0000-4000-e000-00000000000a');
SELECT pg_temp.expect_denied('authenticated executes purge_stale_card_states',
  $q$SELECT public.purge_stale_card_states()$q$);
SELECT pg_temp.act_as_anon();
SELECT pg_temp.expect_denied('anon executes purge_stale_card_states',
  $q$SELECT public.purge_stale_card_states()$q$);
RESET ROLE;

SELECT pg_temp.expect_true('purge returns the number of rows deleted',
  public.purge_stale_card_states() = 4);
SELECT pg_temp.expect_true('only the stale rows are gone',
  (SELECT array_agg(card_key COLLATE "C" ORDER BY card_key COLLATE "C") FROM public.user_card_states
   WHERE user_id = '00000000-0000-4000-e000-00000000000c')
  = ARRAY['old_snoozed:1', 'onboarding:birthday', 'onboarding:optional_window',
          'onboarding:photo', 'recent:1', 'recent_dismissed:1']::text[]);
SELECT pg_temp.expect_true('a second purge deletes nothing', public.purge_stale_card_states() = 0);

-- Scheduled once a year with pg_cron
SELECT pg_temp.expect_true('purge job is scheduled on January 2',
  (SELECT count(*) = 1 AND bool_and(schedule = '17 3 2 1 *' AND command LIKE '%purge_stale_card_states%')
   FROM cron.job WHERE jobname = 'purge-user-card-states'));

-- Deleting the user deletes their rows
DELETE FROM auth.users WHERE id = '00000000-0000-4000-e000-00000000000a';
SELECT pg_temp.expect_true('rows go with the user',
  NOT EXISTS (SELECT 1 FROM public.user_card_states
              WHERE user_id = '00000000-0000-4000-e000-00000000000a'));

ROLLBACK;
