-- Distribution of the "profil de l'annee" of the year recap. Read-only.
--
-- Run as postgres in the SQL editor (the internal functions have no EXECUTE
-- for clients). Change the year in the first CTE. Only users with some
-- activity in the year are counted. It runs the stats of every profile: on a
-- large base, restrict `users` first.
--
-- Use it to tune year_recap_profiles (threshold, weight, enabled, sort):
-- UPDATE public.year_recap_profiles SET threshold = 10, updated_at = now() WHERE key = 'gate';

WITH params AS (
  SELECT 2026 AS year
), recap AS (
  SELECT
    p.id AS user_id,
    s.stats,
    public.year_recap_pick_profile(s.stats) AS profile
  FROM public.profiles p
  CROSS JOIN params
  CROSS JOIN LATERAL (SELECT public.year_recap_stats(p.id, params.year) AS stats) s
  WHERE
    (s.stats ->> 'received')::int
    + (s.stats ->> 'offered')::int
    + (s.stats ->> 'wishes_added')::int
    + (s.stats ->> 'new_friends')::int
    + (s.stats ->> 'bookings_total')::int > 0
), per_profile AS (
  SELECT
    r.profile ->> 'key' AS profile,
    count(*) AS users,
    round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
  FROM recap r
  GROUP BY 1
)
SELECT 'profile' AS section, profile AS name, users::numeric AS v1, pct AS v2,
       NULL::numeric AS v3, NULL::numeric AS v4, NULL::numeric AS v5, NULL::numeric AS v6
FROM per_profile
UNION ALL
-- Percentiles of each stat (NULL = meaningless for the user, ignored by percentile_cont): v1 = p50, v2 = p75, v3 = p90, v4 = p95, v5 = max, v6 = users above 0
SELECT 'stat', m.name,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY m.value)::numeric,
       percentile_cont(0.75) WITHIN GROUP (ORDER BY m.value)::numeric,
       percentile_cont(0.9) WITHIN GROUP (ORDER BY m.value)::numeric,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY m.value)::numeric,
       max(m.value),
       count(*) FILTER (WHERE m.value > 0)
FROM recap r
CROSS JOIN LATERAL (VALUES
  ('received', (r.stats ->> 'received')::numeric),
  ('offered', (r.stats ->> 'offered')::numeric),
  ('longest_awaited_days', (r.stats -> 'longest_awaited' ->> 'days')::numeric),
  ('wishes_added', (r.stats ->> 'wishes_added')::numeric),
  ('new_friends', (r.stats ->> 'new_friends')::numeric),
  ('max_offered_same_friend', (r.stats ->> 'max_offered_same_friend')::numeric),
  ('last_minute_bookings', (r.stats ->> 'last_minute_bookings')::numeric),
  ('bookings_total', (r.stats ->> 'bookings_total')::numeric),
  ('last_minute_share', CASE WHEN (r.stats ->> 'bookings_total')::int > 0 THEN (r.stats ->> 'last_minute_share')::numeric END),
  ('received_on_party_day', (r.stats ->> 'received_on_party_day')::numeric)
) AS m(name, value)
GROUP BY m.name
ORDER BY section DESC, name;
