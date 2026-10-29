-- Remember, per user and per precise card, what was shown and what was
-- dismissed on the home screen. The cards themselves are computed by the app
-- (see home_cards); this table only keeps the device-independent state.
--
-- Card keys: <home_cards.key>:<id>[:<year>], one per occurrence of a card.
-- Examples: booked_reminder:4512, friend_birthday:<uuid>:2026,
-- stale_wishlist:88, after_party:2026, christmas:2026.
--
-- A card is hidden when dismissed_at is set and snoozed_until is NULL or in
-- the future. A card dismissed without a snooze never comes back. The app
-- applies this rule, the table does not.
--
-- Clients only read their rows. They write through record_card_shown and
-- dismiss_card, which always write the row of the current user.

CREATE TABLE IF NOT EXISTS public.user_card_states (
  user_id uuid NOT NULL
    REFERENCES public.profiles (id) ON UPDATE CASCADE ON DELETE CASCADE,
  card_key text NOT NULL CHECK (char_length(card_key) <= 200),
  shown_count integer NOT NULL DEFAULT 0,
  last_shown_at timestamptz,
  dismissed_at timestamptz,
  snoozed_until timestamptz,
  PRIMARY KEY (user_id, card_key)
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
-- after that date, without it never.
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

  INSERT INTO public.user_card_states (user_id, card_key, dismissed_at, snoozed_until)
  VALUES (v_user_id, p_card_key, now(), p_snooze_until)
  ON CONFLICT (user_id, card_key) DO UPDATE
    SET dismissed_at = now(),
        snoozed_until = p_snooze_until;
END;
$$;

REVOKE ALL ON FUNCTION public.record_card_shown(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_card_shown(text) TO authenticated;
REVOKE ALL ON FUNCTION public.dismiss_card(text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dismiss_card(text, timestamptz) TO authenticated;

-- Tests: supabase-tests/user_card_states.sql.
