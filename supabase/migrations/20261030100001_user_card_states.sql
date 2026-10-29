-- Remember, per user and per precise card, what was shown and what was
-- dismissed on the home screen. The cards themselves are computed by the app
-- (see home_cards); this table only keeps the state shared by all the user's
-- devices.
--
-- Card keys: <home_cards.key>:<id>[:<year>], one per occurrence of a card.
-- Examples: booked_reminder:4512, friend_birthday:<uuid>:2026,
-- stale_wishlist:88, after_party:2026, christmas:2026.
--
-- A card is hidden when dismissed_at is set and snoozed_until is NULL or in
-- the future. A card dismissed without a snooze never comes back. A mask is
-- never shortened: a permanent mask stays permanent, and a snooze only moves
-- later (a late "later" from a stale device must not bring a hidden card back);
-- "later" then "hide" does end permanent. dismiss_card applies this rule; the
-- app applies the visibility rule above.
--
-- Rows accumulate (one per card occurrence), so purge_stale_card_states
-- deletes them once a year (pg_cron, January 2). A row is stale when it was
-- last shown or dismissed more than a year ago and holds no snooze still to
-- come. A permanent mask (dismissed, no snooze) is the exception: it never
-- gets activity again yet must keep holding, so it is only purged once its
-- year is over, that is when its key ends with a year older than the current
-- one (friend_birthday:<uuid>:2020, the card cannot come back for that year).
-- A permanent mask without a year (stale_wishlist:88, booked_reminder:4512) is
-- kept for good.
-- Rows whose key starts with 'onboarding:' are never purged: onboarding:birthday,
-- onboarding:photo and onboarding:optional_window have no year in their key,
-- deleting them would bring the skipped onboarding steps back.
--
-- Clients only read their rows. They write through record_card_shown and
-- dismiss_card, which always write the row of the current user.

CREATE TABLE IF NOT EXISTS public.user_card_states (
  user_id uuid NOT NULL
    REFERENCES public.profiles (id) ON UPDATE CASCADE ON DELETE CASCADE,
  card_key text NOT NULL,
  shown_count integer NOT NULL DEFAULT 0,
  last_shown_at timestamptz,
  dismissed_at timestamptz,
  snoozed_until timestamptz,
  PRIMARY KEY (user_id, card_key),
  CONSTRAINT user_card_states_card_key_length CHECK (char_length(card_key) BETWEEN 1 AND 200)
);

ALTER TABLE public.user_card_states ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.user_card_states FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.user_card_states TO authenticated;

DROP POLICY IF EXISTS "Users read their own card states" ON public.user_card_states;
CREATE POLICY "Users read their own card states"
  ON public.user_card_states
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Policies add up (OR): fail if a permissive policy other than the one above
-- exists on the table (CREATE TABLE IF NOT EXISTS keeps a table that already
-- exists, with its policies), and if anon or PUBLIC got a privilege on it.
DO $$
DECLARE
  extra text;
BEGIN
  SELECT string_agg(format('"%s" (%s)', policyname, cmd), ', ')
  INTO extra
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'user_card_states'
    AND permissive = 'PERMISSIVE'
    AND policyname NOT IN ('Users read their own card states');
  IF extra IS NOT NULL THEN
    RAISE EXCEPTION 'unexpected permissive policy on user_card_states: %', extra
      USING HINT = 'Drop it: permissive policies add up and would widen who can read card states.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_class c, aclexplode(c.relacl) a
    WHERE c.oid = 'public.user_card_states'::regclass
      AND a.grantee IN (0, 'anon'::regrole)
  ) OR EXISTS (
    SELECT 1
    FROM pg_attribute t, aclexplode(t.attacl) a
    WHERE t.attrelid = 'public.user_card_states'::regclass
      AND t.attnum > 0
      AND a.grantee IN (0, 'anon'::regrole)
  ) THEN
    RAISE EXCEPTION 'anon or PUBLIC still has a privilege on user_card_states';
  END IF;
END $$;

-- The card was shown to the current user: creates the row or counts one more
-- display.
CREATE OR REPLACE FUNCTION public.record_card_shown(p_card_key text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := (SELECT auth.uid());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'insufficient_privilege';
  END IF;

  INSERT INTO public.user_card_states (user_id, card_key, shown_count, last_shown_at)
  VALUES (v_user_id, p_card_key, 1, now())
  ON CONFLICT (user_id, card_key) DO UPDATE
    SET shown_count = public.user_card_states.shown_count + 1,
        last_shown_at = now();
END;
$$;

-- The current user dismissed the card. With p_snooze_until it comes back
-- after that date, without it never. A mask is never shortened (see the
-- header): the later of the two dates wins. A date in the past is accepted, and does
-- not shorten a mask still running; a non-finite one is refused.
CREATE OR REPLACE FUNCTION public.dismiss_card(
  p_card_key text,
  p_snooze_until timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := (SELECT auth.uid());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF p_snooze_until IS NOT NULL AND NOT isfinite(p_snooze_until) THEN
    RAISE EXCEPTION 'snooze_until must be finite' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  INSERT INTO public.user_card_states (user_id, card_key, dismissed_at, snoozed_until)
  VALUES (v_user_id, p_card_key, now(), p_snooze_until)
  ON CONFLICT (user_id, card_key) DO UPDATE
    SET dismissed_at = now(),
        snoozed_until = CASE
          WHEN public.user_card_states.dismissed_at IS NOT NULL
            AND public.user_card_states.snoozed_until IS NULL THEN NULL
          WHEN p_snooze_until IS NULL THEN NULL
          ELSE GREATEST(public.user_card_states.snoozed_until, p_snooze_until)
        END;
END;
$$;

REVOKE ALL ON FUNCTION public.record_card_shown(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_card_shown(text) TO authenticated;
REVOKE ALL ON FUNCTION public.dismiss_card(text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dismiss_card(text, timestamptz) TO authenticated;

-- Deletes the stale rows of every user (see the header for the rule) and returns how many. Internal: run by
-- pg_cron as postgres, so no client can call it. The retention is spelled once,
-- in v_retention.
CREATE OR REPLACE FUNCTION public.purge_stale_card_states()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_retention constant interval := interval '1 year';
  v_deleted integer;
BEGIN
  DELETE FROM public.user_card_states
  WHERE GREATEST(last_shown_at, dismissed_at) < now() - v_retention
    AND (snoozed_until IS NULL OR snoozed_until < now())
    AND card_key NOT LIKE 'onboarding:%'
    -- A permanent mask still in force stays, unless its year is over
    AND (
      dismissed_at IS NULL
      OR snoozed_until IS NOT NULL
      OR (
        card_key ~ ':[0-9]{4}$'
        AND right(card_key, 4)::int < extract(year FROM now())
      )
    );
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_stale_card_states() FROM PUBLIC, anon, authenticated, service_role;

-- Once a year, January 2 at 03:17 UTC. Scheduling by name replaces an existing
-- job, so this stays idempotent.
-- No grant on the cron schema: Supabase's after-create hook of the extension
-- already gives postgres USAGE on it.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

SELECT cron.schedule(
  'purge-user-card-states',
  '17 3 2 1 *',
  $cron$SELECT public.purge_stale_card_states()$cron$
);

-- Tests: supabase-tests/user_card_states.sql.
--
-- Verification:
--   SELECT jobname, schedule, username FROM cron.job
--   WHERE jobname = 'purge-user-card-states'; -- one row, 17 3 2 1 *, postgres
