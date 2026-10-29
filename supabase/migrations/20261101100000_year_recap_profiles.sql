-- "Profil de l'annee" of the year recap: settings table, stats and scoring.
--
-- year_recap_profiles holds one row per profile with the settings that tune
-- the choice: enabled, threshold (the stat at which the profile scores 1),
-- weight (multiplies the score) and sort (tie-break, smaller wins). It is
-- edited by hand in the SQL editor, like home_cards: RLS on, authenticated
-- can only read, nobody can write through the API. Seeds use ON CONFLICT DO
-- NOTHING: a setting changed by hand is never overwritten by a migration.
--
-- The logic of each profile (which stat, when it is eligible) is in
-- year_recap_pick_profile; the table only tunes it. A row whose key the
-- function does not know is ignored.
--
--   key                stat                                           eligible when
--   patient            days the longest awaited wish received in      a wish was received
--                      the year waited                                 in the year
--   pere_noel_discret  offered                                        offered > received
--   gate               received                                       received >= 2 * offered
--   equilibriste       least(offered, received)                       abs(offered - received) <= 1
--   reveur             wishes added to own wishlists in the year      always
--   rassembleur        friendships accepted in the year               always
--   ami_fidele         max offered wishes to the same friend          always
--   dernier_moment     share of bookings made 0 to 3 days before      at least 2 such bookings
--                      Dec 25 or the owner's birthday
--   organise           wishes received on Dec 25 or own birthday      always
--   minimaliste        none: default, chosen when no other profile reaches a score of 1
--
-- score = stat * weight / threshold (multiplied first: 1 * 3 / 3 is exactly 1).
-- The best score wins, a tie goes to the smaller sort. Under 1, minimaliste.
--
-- "Year" = calendar year in Europe/Paris. Definitions (they mirror
-- yearRecapFacts and the booked wishes query of the app):
--   received  rows of user_completed_wishs of the user whose completed_at (a
--             Paris day) is in the year, on a wish whose wishlist exists
--             (archived ones included: a received wish archives its list).
--             One row = one wish, whatever its received quantity.
--   offered   bookings of the user, on wishes of wishlists that exist
--             (archived ones included: a friend who deletes their list after
--             Christmas archives it, the gifts stay offered), whose owner's
--             receipt (user_completed_wishs of the owner of the wishlist) has
--             a quantity >= the booked quantity and a completed_at in the
--             year (a Paris day, fixed when the wish was first marked
--             received). Not updated_at: it moves with every correction of
--             the received quantity, so a gift received in December and
--             corrected in January would change year. A partial receipt does
--             not count.
--             bookings_total and last_minute_bookings follow the same rule
--             on wishlists.
--   longest awaited  the received wish with the longest wait, completed day
--             minus creation day (Paris days), in the year.
-- Difference with the app, on purpose: the year is cut in Paris time, not in
-- the device time zone. Receipts are the same on both sides: a booker can
-- read the wishes they booked and their receipt, even on a private wishlist
-- (can_read_wish).
--
-- last_minute_bookings uses the birthday of the wish owner only when the
-- owner and the user are friends (accepted), the rule of can_read_birthday,
-- evaluated for p_user and not auth.uid(). Without it a user could book a
-- stranger's public wish, move wish_taken_by_user.created_at (client
-- writable) and bisect the birthday through the stat. A non-friend's booking
-- counts for Christmas only. created_at being client writable, the stat can
-- be gamed by its own user (dernier_moment): acceptable, it is a game.
--
-- new_friends uses friendships.updated_at of accepted friendships: the table
-- has no acceptance date, and updated_at is only set by the trigger
-- friendships_before_update, i.e. when the status changes (pending to
-- accepted, or later to blocked and back). A friendship accepted in the year
-- and changed again later is counted by its last change.
--
-- The stat functions are internal (no EXECUTE for clients): they compute for
-- any user. Only get_my_year_recap is public, and only for auth.uid().

CREATE TABLE IF NOT EXISTS public.year_recap_profiles (
  key text PRIMARY KEY,
  enabled boolean NOT NULL DEFAULT true,
  threshold numeric NOT NULL,
  weight numeric NOT NULL DEFAULT 1,
  sort integer NOT NULL,
  -- Path of the illustration in the bucket year-recap-illustrations, filled by
  -- hand; NULL = the app shows its bundled generic illustration.
  illustration_path text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT year_recap_profiles_threshold_positive CHECK (threshold > 0),
  CONSTRAINT year_recap_profiles_weight_positive CHECK (weight > 0)
);

ALTER TABLE public.year_recap_profiles
  ADD COLUMN IF NOT EXISTS illustration_path text;

ALTER TABLE public.year_recap_profiles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.year_recap_profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.year_recap_profiles TO authenticated;

DROP POLICY IF EXISTS "Authenticated users read year recap profiles" ON public.year_recap_profiles;
CREATE POLICY "Authenticated users read year recap profiles"
  ON public.year_recap_profiles
  FOR SELECT
  TO authenticated
  USING (true);

INSERT INTO public.year_recap_profiles (key, threshold, sort) VALUES
  ('patient', 180, 10),
  ('pere_noel_discret', 2, 20),
  ('gate', 8, 30),
  ('equilibriste', 2, 40),
  ('reveur', 15, 50),
  ('rassembleur', 5, 60),
  ('ami_fidele', 3, 70),
  ('dernier_moment', 0.5, 80),
  ('organise', 3, 90),
  ('minimaliste', 1, 100)
ON CONFLICT (key) DO NOTHING;

-- Bucket of the profile illustrations: public read (the app uses public URLs),
-- no storage.objects policy for it, so no client can write: files are uploaded
-- from the dashboard, then year_recap_profiles.illustration_path is set by hand.
-- Same layout as 20261012120000: public, file_size_limit and allowed_mime_types
-- are columns of the storage service, absent from a bare storage schema.
INSERT INTO storage.buckets (id, name)
VALUES ('year-recap-illustrations', 'year-recap-illustrations')
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF (
    SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'storage'
      AND table_name = 'buckets'
      AND column_name IN ('public', 'file_size_limit', 'allowed_mime_types')
  ) = 3 THEN
    UPDATE storage.buckets
    SET public = true,
        file_size_limit = 2097152,
        allowed_mime_types = ARRAY['image/webp', 'image/png']
    WHERE id = 'year-recap-illustrations';
  END IF;
END $$;

-- Day of month/day in a year, February 29 becoming February 28 in a common
-- year (a birthday has no year, see profile_birthdays).
CREATE OR REPLACE FUNCTION public.year_recap_birthday_in(p_month integer, p_day integer, p_year integer)
RETURNS date
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT make_date(
    p_year,
    p_month,
    least(
      p_day,
      extract(day FROM (make_date(p_year, p_month, 1) + interval '1 month' - interval '1 day'))::integer
    )
  );
$$;

REVOKE ALL ON FUNCTION public.year_recap_birthday_in(integer, integer, integer) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.year_recap_stats(p_user uuid, p_year integer)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_start date;
  v_end date;
  v_xmas date;
  v_own_birthday date;
  v_received integer;
  v_offered integer;
  v_longest jsonb;
  v_wishes_added integer;
  v_new_friends integer;
  v_max_same_friend integer;
  v_bookings_total integer;
  v_last_minute integer;
  v_party_received integer;
BEGIN
  IF p_user IS NULL OR p_year IS NULL OR p_year NOT BETWEEN 2000 AND 2100 THEN
    RAISE EXCEPTION 'invalid_year_recap_arguments' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  v_start := make_date(p_year, 1, 1);
  v_end := make_date(p_year, 12, 31);
  v_xmas := make_date(p_year, 12, 25);

  SELECT public.year_recap_birthday_in(b.month, b.day, p_year)
  INTO v_own_birthday
  FROM public.profile_birthdays b
  WHERE b.profile_id = p_user;

  -- Received wishes of the year.
  WITH received AS (
    SELECT c.completed_at,
           w.id AS wish_id,
           w.name AS wish_name,
           (w.created_at AT TIME ZONE 'Europe/Paris')::date AS created_on
    FROM public.user_completed_wishs c
    JOIN public.wishs w ON w.id = c.wish_id
    JOIN public.wishlists wl ON wl.id = w.wishlist_id AND wl.id_owner = p_user
    WHERE c.user_id = p_user
      AND c.completed_at BETWEEN v_start AND v_end
  ), longest AS (
    SELECT r.*
    FROM received r
    ORDER BY (r.completed_at - r.created_on) DESC, r.completed_at, r.wish_id
    LIMIT 1
  )
  SELECT
    (SELECT count(*) FROM received),
    (SELECT jsonb_build_object(
        'wish_id', l.wish_id,
        'wish_name', l.wish_name,
        'created_on', l.created_on,
        'completed_on', l.completed_at,
        'days', greatest(l.completed_at - l.created_on, 0))
     FROM longest l),
    (SELECT count(*) FROM received r WHERE r.completed_at IN (v_xmas, v_own_birthday))
  INTO v_received, v_longest, v_party_received;

  -- Bookings of the year, with the receipt of the owner of the wishlist.
  WITH bookings AS (
    SELECT t.quantity,
           wl.id_owner,
           (t.created_at AT TIME ZONE 'Europe/Paris')::date AS booked_on,
           r.quantity AS received_quantity,
           r.completed_at AS received_on,
           ob.month AS owner_month,
           ob.day AS owner_day
    FROM public.wish_taken_by_user t
    JOIN public.wishs w ON w.id = t.wish_id
    JOIN public.wishlists wl ON wl.id = w.wishlist_id
    LEFT JOIN public.user_completed_wishs r ON r.wish_id = t.wish_id AND r.user_id = wl.id_owner
    LEFT JOIN public.profile_birthdays ob ON ob.profile_id = wl.id_owner
      AND public.friendship_status_between(p_user, wl.id_owner) = 'accepted'
    WHERE t.user_id = p_user
  ), offered AS (
    SELECT b.id_owner
    FROM bookings b
    WHERE b.received_quantity >= b.quantity
      AND b.received_on BETWEEN v_start AND v_end
  ), offered_by_friend AS (
    SELECT o.id_owner, count(*) AS n FROM offered o GROUP BY o.id_owner
  ), booked_in_year AS (
    SELECT b.*
    FROM bookings b
    WHERE b.booked_on BETWEEN v_start AND v_end
  )
  SELECT
    (SELECT count(*) FROM offered),
    COALESCE((SELECT max(n) FROM offered_by_friend), 0),
    (SELECT count(*) FROM booked_in_year),
    (SELECT count(*) FROM booked_in_year b
      WHERE (v_xmas - b.booked_on) BETWEEN 0 AND 3
         OR (b.owner_month IS NOT NULL AND (
               (public.year_recap_birthday_in(b.owner_month, b.owner_day, p_year) - b.booked_on) BETWEEN 0 AND 3
            OR (public.year_recap_birthday_in(b.owner_month, b.owner_day, p_year + 1) - b.booked_on) BETWEEN 0 AND 3)))
  INTO v_offered, v_max_same_friend, v_bookings_total, v_last_minute;

  SELECT count(*)
  INTO v_wishes_added
  FROM public.wishs w
  JOIN public.wishlists wl ON wl.id = w.wishlist_id
  WHERE wl.id_owner = p_user
    AND (w.created_at AT TIME ZONE 'Europe/Paris')::date BETWEEN v_start AND v_end;

  SELECT count(*)
  INTO v_new_friends
  FROM public.friendships f
  WHERE f.status = 'accepted'
    AND p_user IN (f.requester_id, f.receiver_id)
    AND (f.updated_at AT TIME ZONE 'Europe/Paris')::date BETWEEN v_start AND v_end;

  RETURN jsonb_build_object(
    'received', v_received,
    'offered', v_offered,
    'longest_awaited', v_longest,
    'wishes_added', v_wishes_added,
    'new_friends', v_new_friends,
    'max_offered_same_friend', v_max_same_friend,
    'last_minute_bookings', v_last_minute,
    'bookings_total', v_bookings_total,
    'last_minute_share',
      CASE WHEN v_bookings_total = 0 THEN 0
           ELSE round(v_last_minute::numeric / v_bookings_total, 4) END,
    'received_on_party_day', v_party_received
  );
END $$;

REVOKE ALL ON FUNCTION public.year_recap_stats(uuid, integer) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.year_recap_pick_profile(p_stats jsonb)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  WITH s AS (
    SELECT
      COALESCE((p_stats ->> 'received')::numeric, 0) AS received,
      COALESCE((p_stats ->> 'offered')::numeric, 0) AS offered,
      (p_stats -> 'longest_awaited' ->> 'days')::numeric AS awaited_days,
      COALESCE((p_stats ->> 'wishes_added')::numeric, 0) AS wishes_added,
      COALESCE((p_stats ->> 'new_friends')::numeric, 0) AS new_friends,
      COALESCE((p_stats ->> 'max_offered_same_friend')::numeric, 0) AS same_friend,
      COALESCE((p_stats ->> 'last_minute_bookings')::numeric, 0) AS last_minute,
      COALESCE((p_stats ->> 'last_minute_share')::numeric, 0) AS last_minute_share,
      COALESCE((p_stats ->> 'received_on_party_day')::numeric, 0) AS party_received
  ), scored AS (
    -- stat is NULL when the profile is not eligible (or unknown).
    SELECT
      p.key,
      p.sort,
      CASE p.key
        WHEN 'patient' THEN s.awaited_days
        WHEN 'pere_noel_discret' THEN CASE WHEN s.offered > s.received THEN s.offered END
        WHEN 'gate' THEN CASE WHEN s.received >= 2 * s.offered THEN s.received END
        WHEN 'equilibriste' THEN CASE WHEN abs(s.offered - s.received) <= 1 THEN least(s.offered, s.received) END
        WHEN 'reveur' THEN s.wishes_added
        WHEN 'rassembleur' THEN s.new_friends
        WHEN 'ami_fidele' THEN s.same_friend
        WHEN 'dernier_moment' THEN CASE WHEN s.last_minute >= 2 THEN s.last_minute_share END
        WHEN 'organise' THEN s.party_received
      END * p.weight / p.threshold AS score
    FROM public.year_recap_profiles p
    CROSS JOIN s
    WHERE p.enabled
      AND p.key <> 'minimaliste'
  ), best AS (
    SELECT key, score
    FROM scored
    WHERE score >= 1
    ORDER BY score DESC, sort, key
    LIMIT 1
  )
  SELECT COALESCE(
    (SELECT jsonb_build_object('key', b.key, 'score', round(b.score, 4)) FROM best b),
    jsonb_build_object('key', 'minimaliste', 'score', 0)
  );
$$;

REVOKE ALL ON FUNCTION public.year_recap_pick_profile(jsonb) FROM PUBLIC, anon, authenticated;

-- Public entry point: the recap of the current user.
-- Returns {"year": 2026, "stats": {...year_recap_stats...}, "profile": {"key": "...", "score": 1.5, "illustration_path": null}}.
-- p_year defaults to the current year in Paris when null.
CREATE OR REPLACE FUNCTION public.get_my_year_recap(p_year integer DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_year integer := COALESCE(p_year, extract(year FROM public.paris_today())::integer);
  v_stats jsonb;
  v_profile jsonb;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = 'invalid_authorization_specification';
  END IF;
  v_stats := public.year_recap_stats(v_user, v_year);
  v_profile := public.year_recap_pick_profile(v_stats);
  RETURN jsonb_build_object(
    'year', v_year,
    'stats', v_stats,
    'profile', v_profile || jsonb_build_object(
      'illustration_path',
      (SELECT p.illustration_path FROM public.year_recap_profiles p WHERE p.key = v_profile ->> 'key')
    )
  );
END $$;

REVOKE ALL ON FUNCTION public.get_my_year_recap(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_year_recap(integer) TO authenticated;

-- Distribution of the profiles over the users: supabase/queries/year_recap_profile_distribution.sql.
-- Tests: supabase-tests/year_recap_profiles.sql.
