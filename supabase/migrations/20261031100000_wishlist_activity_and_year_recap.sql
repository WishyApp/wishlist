-- Last activity of each wishlist, server-side updated_at triggers, and the
-- card "Ton année Wishy".
--
-- get_my_wishlists_last_activity() feeds the home card "stale wishlist": for
-- each wishlist of the caller it returns the most recent of
--   - the wishlist creation date and its updated_at (see trigger 2),
--   - the creation and modification dates of its wishes,
--   - the creation and update dates of the wishes received from it
--     (user_completed_wishs.from_wishlist_id).
-- An empty wishlist is as old as its creation. Deleting a wish leaves no trace
-- in the database, so it does not count as activity.
--
-- Not returned: archived wishlists (deleted_at), closed ones (is_closed) and
-- those whose end_date is before today in Paris. They are inactive on purpose,
-- the card must not flag them. The app does not set is_closed and end_date yet.
--
-- 1. wishs.updated_at is set by the server on every UPDATE. It used to come
--    from the device clock (wrong clocks make a list look active or abandoned),
--    and restore_completed_wish moves a wish without writing it. updated_by is
--    left to the client.
-- 2. wishlists.updated_at is set by the server when something other than
--    "order", updated_at and updated_by changes (rename, visibility, end date,
--    archiving...). A pure reorder, which the app sends with a fresh
--    updated_at, keeps the old value: reordering is not activity.
--    Rows reordered before this migration may still carry an updated_at coming
--    from an old reorder: for them the date can be too recent, never too old.
--
-- SECURITY DEFINER with an explicit id_owner = auth.uid() filter: the read
-- policies also let public and booked lists through, and under INVOKER the
-- policy of wishs would call can_read_wish for every joined wish. EXECUTE is
-- only for authenticated; without a user id the filter matches nothing.
--
-- The year_recap row follows the same rule as the other seeds of home_cards:
-- ON CONFLICT DO NOTHING, a value changed by hand is never overwritten.

CREATE OR REPLACE FUNCTION public.set_wishs_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_wishs_updated_at ON public.wishs;
CREATE TRIGGER set_wishs_updated_at
  BEFORE UPDATE ON public.wishs
  FOR EACH ROW
  EXECUTE FUNCTION public.set_wishs_updated_at();

CREATE OR REPLACE FUNCTION public.set_wishlists_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF (to_jsonb(NEW) - 'order' - 'updated_at' - 'updated_by')
     IS DISTINCT FROM (to_jsonb(OLD) - 'order' - 'updated_at' - 'updated_by') THEN
    NEW.updated_at = now();
  ELSE
    NEW.updated_at = OLD.updated_at;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_wishlists_updated_at ON public.wishlists;
CREATE TRIGGER set_wishlists_updated_at
  BEFORE UPDATE ON public.wishlists
  FOR EACH ROW
  EXECUTE FUNCTION public.set_wishlists_updated_at();

CREATE OR REPLACE FUNCTION public.get_my_wishlists_last_activity()
RETURNS TABLE (wishlist_id bigint, last_activity_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    wl.id,
    GREATEST(
      wl.created_at,
      wl.updated_at,
      (SELECT max(GREATEST(w.created_at, w.updated_at))
         FROM public.wishs w WHERE w.wishlist_id = wl.id),
      (SELECT max(GREATEST(c.created_at, c.updated_at))
         FROM public.user_completed_wishs c WHERE c.from_wishlist_id = wl.id)
    )
  FROM public.wishlists wl
  WHERE wl.id_owner = (SELECT auth.uid())
    AND wl.deleted_at IS NULL
    AND NOT wl.is_closed
    AND (wl.end_date IS NULL
         OR (wl.end_date AT TIME ZONE 'Europe/Paris')::date
            >= (now() AT TIME ZONE 'Europe/Paris')::date);
$$;

REVOKE ALL ON FUNCTION public.get_my_wishlists_last_activity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_wishlists_last_activity() TO authenticated;

INSERT INTO public.home_cards (key, kind, priority, params) VALUES
  ('year_recap', 'computed', 28, '{"month": 12}')
ON CONFLICT (key) DO NOTHING;
