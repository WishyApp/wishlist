-- Last activity of each wishlist, and the card "Ton année Wishy".
--
-- get_my_wishlists_last_activity() feeds the home card "stale wishlist": it
-- returns, for each non-archived wishlist of the caller, the most recent of the
-- wishlist creation date and the creation and modification dates of its wishes.
-- An empty wishlist is as old as its creation. Deleting a wish leaves no trace
-- in the database, so it does not count as activity.
--
-- wishlists.updated_at is not used on purpose: reordering the wishlists
-- rewrites it, so it says nothing about what the user did in the list.
--
-- SECURITY INVOKER: the read policies of wishlists and wishs already let the
-- owner read their own rows, and the explicit id_owner filter keeps the
-- result to the caller's lists (the policies also let public lists through).
--
-- The year_recap row follows the same rule as the other seeds of home_cards:
-- ON CONFLICT DO NOTHING, a value changed by hand is never overwritten.

CREATE OR REPLACE FUNCTION public.get_my_wishlists_last_activity()
RETURNS TABLE (wishlist_id bigint, last_activity_at timestamptz)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT
    wl.id,
    GREATEST(wl.created_at, max(w.created_at), max(w.updated_at))
  FROM public.wishlists wl
  LEFT JOIN public.wishs w ON w.wishlist_id = wl.id
  WHERE wl.id_owner = (SELECT auth.uid())
    AND wl.deleted_at IS NULL
  GROUP BY wl.id, wl.created_at;
$$;

REVOKE ALL ON FUNCTION public.get_my_wishlists_last_activity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_wishlists_last_activity() TO authenticated;

INSERT INTO public.home_cards (key, kind, priority, params) VALUES
  ('year_recap', 'computed', 28, '{"month": 12}')
ON CONFLICT (key) DO NOTHING;
