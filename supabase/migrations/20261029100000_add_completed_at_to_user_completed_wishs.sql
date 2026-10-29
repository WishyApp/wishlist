-- Store the day a completed wish was received, chosen by the user, instead of
-- reading it from created_at (the day the row was inserted).
--
-- A date, not a timestamp: the user picks a day in a calendar, and a day has
-- no time zone to convert. created_at keeps the insert time, and still orders
-- the wishes completed on the same day.
--
-- One row per user and wish holds the received quantity of the wish: when
-- more of it is received, the app keeps the most recent of the two days.
--
-- App versions released before this migration do not send completed_at: the
-- default gives them the current day, as they showed until now. They keep
-- reading created_at.

-- 1. Column. Rows inserted before this migration get the day of their insert,
-- in the time zone of the app's users: the day they saw in the app.
--
-- The trigger of updated_at is off during the backfill: the rows keep the time
-- of their last change by a user. The backfill still sends one realtime UPDATE
-- per row, once, to the clients connected at that time.
ALTER TABLE public.user_completed_wishs
  ADD COLUMN IF NOT EXISTS completed_at date;

ALTER TABLE public.user_completed_wishs
  DISABLE TRIGGER set_user_completed_wishs_updated_at;

UPDATE public.user_completed_wishs
  SET completed_at = (created_at AT TIME ZONE 'Europe/Paris')::date
  WHERE completed_at IS NULL;

ALTER TABLE public.user_completed_wishs
  ENABLE TRIGGER set_user_completed_wishs_updated_at;

ALTER TABLE public.user_completed_wishs
  ALTER COLUMN completed_at SET DEFAULT (now() AT TIME ZONE 'Europe/Paris')::date,
  ALTER COLUMN completed_at SET NOT NULL;

-- 2. Column privileges: completed_at joins quantity, the only columns the app
-- updates (see 20260517000000_add_quantity_to_user_completed_wishs). The
-- REVOKE and the GRANT stay together: a table-level REVOKE also revokes column
-- privileges, so the pair can be replayed safely.
REVOKE UPDATE ON public.user_completed_wishs FROM anon, authenticated;
GRANT UPDATE (quantity, completed_at) ON public.user_completed_wishs TO authenticated;


-- Verification: tests in supabase-tests/write_policies.sql.
--
-- SELECT column_name, data_type, is_nullable, column_default
--   FROM information_schema.columns
--  WHERE table_schema = 'public' AND table_name = 'user_completed_wishs'
--    AND column_name = 'completed_at';
--   -> date, NO, (now() AT TIME ZONE 'Europe/Paris'::text)::date
--
-- SELECT column_name FROM information_schema.column_privileges
--  WHERE table_schema = 'public' AND table_name = 'user_completed_wishs'
--    AND grantee = 'authenticated' AND privilege_type = 'UPDATE';
--   -> quantity, completed_at
