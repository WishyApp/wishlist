-- home_cards (20261030100000_home_cards): seeds, access rules and the
-- constraint on hand-written editorial cards.
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

CREATE FUNCTION pg_temp.expect_denied(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: allowed, expected a denial', label;
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'ok   % (denied)', label;
END $$;

CREATE FUNCTION pg_temp.expect_check_violation(label text, statement text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE statement;
  RAISE EXCEPTION 'FAIL %: accepted, expected a check violation', label;
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'ok   % (refused)', label;
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
  PERFORM set_config('request.jwt.claim.sub', user_id::text, true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
END $$;

-- Seeds and catalog
CREATE TEMP TABLE expected_seeds (key text, kind text, priority int, params jsonb);
INSERT INTO pg_temp.expected_seeds VALUES
  ('home_stack', 'settings', 0, '{"max_cards": 3, "later_days": 1}'),
  ('friend_birthday_today', 'computed', 10, '{}'),
  ('after_party', 'computed', 15, '{"days_after": 7}'),
  ('onboarding', 'computed', 18, '{"optional_steps_hours": 48}'),
  ('booked_reminder', 'computed', 20, '{"days_before": 14}'),
  ('booked_wish_removed', 'computed', 25, '{}'),
  ('year_recap', 'computed', 28, '{"month": 12}'),
  ('friend_birthday', 'computed', 30, '{"reminder_days": [30, 7], "highlight_days": 7}'),
  ('friend_accepted', 'computed', 35, '{"days": 7}'),
  ('christmas', 'computed', 40,
   '{"reminder_days": [30, 7], "highlight_days": 7, "keywords": ["noel", "christmas", "xmas"]}'),
  ('stale_wishlist', 'computed', 60, '{"stale_days": 90, "snooze_days": 60}');
DO $$
DECLARE
  k text;
BEGIN
  FOREACH k IN ARRAY ARRAY['friend_birthday_today', 'after_party', 'onboarding',
    'booked_reminder', 'booked_wish_removed', 'year_recap', 'friend_birthday',
    'friend_accepted', 'christmas', 'stale_wishlist'] LOOP
    IF NOT EXISTS (SELECT 1 FROM public.home_cards WHERE key = k AND kind = 'computed') THEN
      RAISE EXCEPTION 'FAIL computed card % is not seeded', k;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM public.home_cards WHERE key = 'home_stack' AND kind = 'settings') THEN
    RAISE EXCEPTION 'FAIL home_stack is not seeded as settings';
  END IF;
  IF EXISTS (
    (SELECT key, kind, priority, params FROM public.home_cards
     EXCEPT
     SELECT * FROM pg_temp.expected_seeds)
    UNION ALL
    (SELECT * FROM pg_temp.expected_seeds
     EXCEPT
     SELECT key, kind, priority::int, params FROM public.home_cards)
  ) THEN
    RAISE EXCEPTION 'FAIL seeded rows differ from the expected ones';
  END IF;
  IF (SELECT params->'reminder_days' FROM public.home_cards WHERE key = 'christmas')
     IS DISTINCT FROM '[30, 7]'::jsonb THEN
    RAISE EXCEPTION 'FAIL christmas reminder_days';
  END IF;
  IF (SELECT params->'keywords' FROM public.home_cards WHERE key = 'christmas')
     IS DISTINCT FROM '["noel", "christmas", "xmas"]'::jsonb THEN
    RAISE EXCEPTION 'FAIL christmas keywords';
  END IF;
  IF (SELECT params->>'stale_days' FROM public.home_cards WHERE key = 'stale_wishlist')
     IS DISTINCT FROM '90' THEN
    RAISE EXCEPTION 'FAIL stale_wishlist stale_days';
  END IF;
  RAISE NOTICE 'ok   seeds: 11 rows with the expected kinds and params';

  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.home_cards'::regclass) THEN
    RAISE EXCEPTION 'FAIL RLS is off on home_cards';
  END IF;
  IF has_table_privilege('anon', 'public.home_cards', 'SELECT')
     OR has_table_privilege('anon', 'public.home_cards', 'INSERT')
     OR has_table_privilege('anon', 'public.home_cards', 'UPDATE')
     OR has_table_privilege('anon', 'public.home_cards', 'DELETE') THEN
    RAISE EXCEPTION 'FAIL anon has a privilege on home_cards';
  END IF;
  IF NOT has_table_privilege('authenticated', 'public.home_cards', 'SELECT') THEN
    RAISE EXCEPTION 'FAIL authenticated cannot SELECT home_cards';
  END IF;
  IF has_table_privilege('authenticated', 'public.home_cards', 'INSERT')
     OR has_table_privilege('authenticated', 'public.home_cards', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.home_cards', 'DELETE') THEN
    RAISE EXCEPTION 'FAIL authenticated can write home_cards';
  END IF;
  RAISE NOTICE 'ok   catalog: RLS on, anon nothing, authenticated read only';
END $$;

-- Constraint on editorial cards (as postgres)
SELECT pg_temp.expect_check_violation('editorial without an english title',
  $q$INSERT INTO public.home_cards (key, kind, priority, event_on, starts_at, ends_at, title)
     VALUES ('t_no_en', 'editorial', 45, current_date, now() - interval '1 day',
             now() + interval '1 day', '{"fr": "Salut"}')$q$);
SELECT pg_temp.expect_check_violation('editorial without a title',
  $q$INSERT INTO public.home_cards (key, kind, priority, event_on, starts_at, ends_at)
     VALUES ('t_no_title', 'editorial', 45, current_date, now() - interval '1 day',
             now() + interval '1 day')$q$);
SELECT pg_temp.expect_check_violation('editorial ending before it starts',
  $q$INSERT INTO public.home_cards (key, kind, priority, event_on, starts_at, ends_at, title)
     VALUES ('t_backwards', 'editorial', 45, current_date, now() + interval '1 day',
             now() - interval '1 day', '{"fr": "a", "en": "a"}')$q$);
SELECT pg_temp.expect_check_violation('editorial without event_on',
  $q$INSERT INTO public.home_cards (key, kind, priority, starts_at, ends_at, title)
     VALUES ('t_no_event', 'editorial', 45, current_date - interval '1 day',
             now() + interval '1 day', '{"fr": "a", "en": "a"}')$q$);
SELECT pg_temp.expect_check_violation('editorial without a window',
  $q$INSERT INTO public.home_cards (key, kind, priority, event_on, title)
     VALUES ('t_no_window', 'editorial', 45, current_date, '{"fr": "a", "en": "a"}')$q$);
SELECT pg_temp.expect_check_violation('key with spaces and capitals',
  $q$INSERT INTO public.home_cards (key, kind, priority) VALUES ('Noël 2026', 'computed', 45)$q$);
SELECT pg_temp.expect_check_violation('key ascii with a space',
  $q$INSERT INTO public.home_cards (key, kind, priority) VALUES ('Noel 2026', 'computed', 45)$q$);
SELECT pg_temp.expect_check_violation('key with a capital',
  $q$INSERT INTO public.home_cards (key, kind, priority) VALUES ('Christmas', 'computed', 45)$q$);
SELECT pg_temp.expect_check_violation('editorial with title as an array',
  $q$INSERT INTO public.home_cards (key, kind, priority, event_on, starts_at, ends_at, title)
     VALUES ('t_arr', 'editorial', 45, current_date, now() - interval '1 day',
             now() + interval '1 day', '["fr", "en"]')$q$);
SELECT pg_temp.expect_check_violation('editorial with a null french title',
  $q$INSERT INTO public.home_cards (key, kind, priority, event_on, starts_at, ends_at, title)
     VALUES ('t_nullfr', 'editorial', 45, current_date, now() - interval '1 day',
             now() + interval '1 day', '{"fr": null, "en": "x"}')$q$);
SELECT pg_temp.expect_check_violation('params as an array',
  $q$INSERT INTO public.home_cards (key, kind, priority, params)
     VALUES ('t_params', 'computed', 45, '[]')$q$);
SELECT pg_temp.expect_check_violation('cta_label as a string',
  $q$INSERT INTO public.home_cards (key, kind, priority, cta_label)
     VALUES ('t_cta', 'computed', 45, '"Voir"')$q$);
SELECT pg_temp.expect_check_violation('body as an array',
  $q$INSERT INTO public.home_cards (key, kind, priority, body)
     VALUES ('t_body', 'computed', 45, '["x"]')$q$);
SELECT pg_temp.expect_check_violation('body with a null value',
  $q$INSERT INTO public.home_cards (key, kind, priority, body)
     VALUES ('t_body_null', 'computed', 45, '{"fr": "x", "en": null}')$q$);
SELECT pg_temp.expect_check_violation('title with a null value in a third language',
  $q$INSERT INTO public.home_cards (key, kind, priority, event_on, starts_at, ends_at, title)
     VALUES ('t_title_de', 'editorial', 45, current_date, now() - interval '1 day',
             now() + interval '1 day', '{"fr": "a", "en": "b", "de": null}')$q$);
SELECT pg_temp.expect_check_violation('body with an array value',
  $q$INSERT INTO public.home_cards (key, kind, priority, body)
     VALUES ('t_body_arr', 'computed', 45, '{"fr": ["x"], "en": "y"}')$q$);
SELECT pg_temp.expect_check_violation('title with an array value',
  $q$INSERT INTO public.home_cards (key, kind, priority, event_on, starts_at, ends_at, title)
     VALUES ('t_title_arr', 'editorial', 45, current_date, now() - interval '1 day',
             now() + interval '1 day', '{"fr": "a", "en": ["b"]}')$q$);
SELECT pg_temp.expect_check_violation('cta_label with an empty array value',
  $q$INSERT INTO public.home_cards (key, kind, priority, cta_label, cta_route)
     VALUES ('t_cta_arr', 'computed', 45, '{"fr": []}', '/')$q$);
SELECT pg_temp.expect_check_violation('cta_label without english',
  $q$INSERT INTO public.home_cards (key, kind, priority, cta_label, cta_route)
     VALUES ('t_cta_fr', 'computed', 45, '{"fr": "a"}', '/')$q$);
SELECT pg_temp.expect_check_violation('cta_label empty object',
  $q$INSERT INTO public.home_cards (key, kind, priority, cta_label, cta_route)
     VALUES ('t_cta_empty', 'computed', 45, '{}', '/')$q$);
SAVEPOINT accepted_shapes;
-- Still accepted: empty or partial body, and a complete button
INSERT INTO public.home_cards (key, kind, priority, body) VALUES
  ('t_body_empty', 'computed', 48, '{}'),
  ('t_body_fr', 'computed', 48, '{"fr": "a"}');
INSERT INTO public.home_cards (key, kind, priority, cta_label, cta_route) VALUES
  ('t_cta_ok', 'computed', 48, '{"fr": "a", "en": "b"}', '/');
ROLLBACK TO accepted_shapes;
SELECT pg_temp.expect_check_violation('cta_label with a number value',
  $q$INSERT INTO public.home_cards (key, kind, priority, cta_label, cta_route)
     VALUES ('t_cta_num', 'computed', 45, '{"fr": 1}', '/')$q$);
SELECT pg_temp.expect_check_violation('cta_label without a route',
  $q$INSERT INTO public.home_cards (key, kind, priority, cta_label)
     VALUES ('t_cta_label', 'computed', 45, '{"fr": "a", "en": "a"}')$q$);
SELECT pg_temp.expect_check_violation('cta_route without a label',
  $q$INSERT INTO public.home_cards (key, kind, priority, cta_route)
     VALUES ('t_cta_route', 'computed', 45, '/')$q$);
SELECT pg_temp.expect_check_violation('unknown kind',
  $q$INSERT INTO public.home_cards (key, kind, priority) VALUES ('t_kind', 'banner', 45)$q$);

-- Fixtures for the read policy
INSERT INTO public.home_cards (key, kind, priority, event_on, starts_at, ends_at, title) VALUES
  ('t_live', 'editorial', 45, current_date, now() - interval '1 day', now() + interval '1 day',
   '{"fr": "a", "en": "a"}'),
  ('t_over', 'editorial', 46, current_date - 2, now() - interval '2 days',
   now() - interval '1 hour', '{"fr": "a", "en": "a"}'),
  ('t_future', 'editorial', 47, current_date + 3, now() + interval '2 days',
   now() + interval '4 days', '{"fr": "a", "en": "a"}');
INSERT INTO public.home_cards (key, kind, priority, enabled) VALUES
  ('t_disabled', 'computed', 48, false);
INSERT INTO public.home_cards (key, kind, priority, enabled, event_on, starts_at, ends_at, title) VALUES
  ('t_live_disabled', 'editorial', 49, false, current_date, now() - interval '1 day',
   now() + interval '1 day', '{"fr": "a", "en": "a"}');

SELECT pg_temp.act_as('00000000-0000-4000-c000-0000000000c1');
DO $$
DECLARE
  keys text[];
BEGIN
  SELECT array_agg(key) INTO keys FROM public.home_cards WHERE key LIKE 't\_%';
  IF keys IS DISTINCT FROM ARRAY['t_live'] THEN
    RAISE EXCEPTION 'FAIL authenticated sees test rows %, expected only t_live', keys;
  END IF;
  IF (SELECT count(*) FROM public.home_cards) <> 12 THEN
    RAISE EXCEPTION 'FAIL authenticated sees % rows, expected the 11 seeds and t_live',
      (SELECT count(*) FROM public.home_cards);
  END IF;
  RAISE NOTICE 'ok   authenticated reads active rows only (live window, enabled)';
END $$;
SELECT pg_temp.expect_denied('authenticated inserts a card',
  $q$INSERT INTO public.home_cards (key, kind, priority) VALUES ('t_ins', 'computed', 1)$q$);
SELECT pg_temp.expect_denied('authenticated updates a card',
  $q$UPDATE public.home_cards SET enabled = false$q$);
SELECT pg_temp.expect_denied('authenticated deletes a card',
  $q$DELETE FROM public.home_cards$q$);

RESET ROLE;
SELECT pg_temp.act_as_anon();
SELECT pg_temp.expect_denied('anon reads home_cards', $q$SELECT * FROM public.home_cards$q$);

ROLLBACK;
