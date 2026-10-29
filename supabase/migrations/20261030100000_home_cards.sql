-- Cards of the home screen, one row per card type, plus the stack settings.
--
-- kind says what a row is:
--   computed  a card whose logic lives in the app (birthdays, bookings, after
--             party, Christmas...). The row only tunes it: enabled, priority
--             (smaller = more urgent) and params (thresholds, reminder steps).
--             Texts are in the app translations, so the seeds have none.
--   editorial a one-off card (an occasion, an announcement) written by hand:
--             texts in fr and en, display window, optional CTA. It needs no
--             app release.
--   settings  not a card: settings of the stack itself (home_stack).
--
-- The table is edited by hand in the SQL editor, like app_versions: RLS on,
-- authenticated can only read, nobody can write through the API. A bad
-- editorial row would show an empty or endless card, so the CHECK
-- home_cards_editorial_complete refuses it. The procedure for an editorial
-- card is in docs/supabase-migrations.md, "Cartes de l'accueil".
--
-- keywords (christmas): lower case, without accents. The home screen (next
-- change) will match them against wishlist names.
--
-- Seeds use ON CONFLICT DO NOTHING: a setting changed by hand is never
-- overwritten by a migration.

CREATE TABLE IF NOT EXISTS public.home_cards (
  key text PRIMARY KEY,
  kind text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  priority smallint NOT NULL,
  params jsonb NOT NULL DEFAULT '{}',
  -- Calendar day of the occasion (no time zone), starts_at / ends_at are instants.
  event_on date,
  starts_at timestamptz,
  ends_at timestamptz,
  title jsonb,
  body jsonb,
  cta_label jsonb,
  cta_route text,
  illustration text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'home_cards_key_format'
      AND conrelid = 'public.home_cards'::regclass
  ) THEN
    ALTER TABLE public.home_cards
      ADD CONSTRAINT home_cards_key_format CHECK (key ~ '^[a-z0-9_]+$');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'home_cards_kind_check'
      AND conrelid = 'public.home_cards'::regclass
  ) THEN
    ALTER TABLE public.home_cards
      ADD CONSTRAINT home_cards_kind_check
      CHECK (kind IN ('computed', 'editorial', 'settings'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'home_cards_params_object'
      AND conrelid = 'public.home_cards'::regclass
  ) THEN
    ALTER TABLE public.home_cards
      ADD CONSTRAINT home_cards_params_object CHECK (jsonb_typeof(params) = 'object');
  END IF;
  -- Texts are objects whose values are all strings (language code -> text):
  -- the app refuses a row with any other value, which would drop the card.
  -- strict: the default lax mode unwraps arrays, so ["x"] would pass.
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'home_cards_texts_objects'
      AND conrelid = 'public.home_cards'::regclass
  ) THEN
    ALTER TABLE public.home_cards
      ADD CONSTRAINT home_cards_texts_objects
      CHECK (
        (title IS NULL OR (
          jsonb_typeof(title) = 'object'
          AND NOT jsonb_path_exists(title, 'strict $.* ? (@.type() != "string")')))
        AND (body IS NULL OR (
          jsonb_typeof(body) = 'object'
          AND NOT jsonb_path_exists(body, 'strict $.* ? (@.type() != "string")')))
        AND (cta_label IS NULL OR (
          jsonb_typeof(cta_label) = 'object'
          AND NOT jsonb_path_exists(cta_label, 'strict $.* ? (@.type() != "string")')))
      );
  END IF;
  -- A button needs its route and a label in fr and en.
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'home_cards_cta_pair'
      AND conrelid = 'public.home_cards'::regclass
  ) THEN
    ALTER TABLE public.home_cards
      ADD CONSTRAINT home_cards_cta_pair
      CHECK (
        (cta_label IS NULL) = (cta_route IS NULL)
        AND (cta_label IS NULL OR COALESCE(
          jsonb_typeof(cta_label->'fr') = 'string'
          AND jsonb_typeof(cta_label->'en') = 'string',
          false))
      );
  END IF;
  -- COALESCE: a NULL operand would make the CHECK pass instead of failing.
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'home_cards_editorial_complete'
      AND conrelid = 'public.home_cards'::regclass
  ) THEN
    ALTER TABLE public.home_cards
      ADD CONSTRAINT home_cards_editorial_complete
      CHECK (
        kind <> 'editorial'
        OR COALESCE(
          event_on IS NOT NULL
          AND starts_at IS NOT NULL
          AND ends_at IS NOT NULL
          AND ends_at > starts_at
          AND jsonb_typeof(title->'fr') = 'string'
          AND jsonb_typeof(title->'en') = 'string',
          false
        )
      );
  END IF;
END $$;

ALTER TABLE public.home_cards ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.home_cards FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.home_cards TO authenticated;

DROP POLICY IF EXISTS "Authenticated users read active home cards" ON public.home_cards;
CREATE POLICY "Authenticated users read active home cards"
  ON public.home_cards
  FOR SELECT
  TO authenticated
  USING (
    enabled
    AND (kind IN ('computed', 'settings') OR now() BETWEEN starts_at AND ends_at)
  );

INSERT INTO public.home_cards (key, kind, priority, params) VALUES
  ('home_stack', 'settings', 0, '{"max_cards": 3, "later_days": 1}'),
  ('friend_birthday_today', 'computed', 10, '{}'),
  ('after_party', 'computed', 15, '{"days_after": 7}'),
  ('onboarding', 'computed', 18, '{"optional_steps_hours": 48}'),
  ('booked_reminder', 'computed', 20, '{"days_before": 14}'),
  ('booked_wish_removed', 'computed', 25, '{}'),
  ('friend_birthday', 'computed', 30, '{"reminder_days": [30, 7], "highlight_days": 7}'),
  ('friend_accepted', 'computed', 35, '{"days": 7}'),
  ('christmas', 'computed', 40,
    '{"reminder_days": [30, 7], "highlight_days": 7, "keywords": ["noel", "christmas", "xmas"]}'),
  ('stale_wishlist', 'computed', 60, '{"stale_days": 90, "snooze_days": 60}')
ON CONFLICT (key) DO NOTHING;
