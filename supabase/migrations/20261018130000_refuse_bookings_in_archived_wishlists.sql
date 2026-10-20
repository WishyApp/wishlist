-- Refuse bookings in an archived wishlist (F089).
--
-- delete_or_archive_wishlist archives a wishlist (wishlists.deleted_at) and
-- keeps its completed wishes. can_book_wish did not check deleted_at, so these
-- wishes stayed bookable by a direct request on wish_taken_by_user (the app
-- does not offer it: it filters archived wishlists).
--
-- can_book_wish now also requires deleted_at IS NULL. Signature, language,
-- volatility, SECURITY INVOKER, search_path and grants are unchanged
-- (20261011000000_restrict_write_policies_to_owner).
--
-- Both the INSERT and the UPDATE policies of wish_taken_by_user call it: in an
-- archived wishlist a booking can no longer be created, nor updated (quantity
-- change, move to another wish). Cancelling stays possible: the DELETE policy
-- only checks user_id, so a booker can always remove a booking they hold there.
-- Bookings already in an archived wishlist are left as they are.
--
-- Verification (as an authenticated user other than the owner):
--   INSERT INTO wish_taken_by_user (wish_id, user_id, quantity)
--     VALUES (<wish of an archived wishlist>, auth.uid(), 1);
--     -- 42501 (row-level security)
--   DELETE FROM wish_taken_by_user WHERE wish_id = <same wish>;  -- allowed
-- Tests: supabase-tests/write_policies.sql.

CREATE OR REPLACE FUNCTION public.can_book_wish(p_wish_id bigint, p_quantity bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.wishs w
    JOIN public.wishlists wl ON wl.id = w.wishlist_id
    WHERE w.id = p_wish_id
      AND wl.id_owner <> (SELECT auth.uid())
      AND wl.visibility = 'public'
      AND NOT wl.is_closed
      AND wl.deleted_at IS NULL
      AND p_quantity BETWEEN 1 AND w.quantity
  );
$$;

REVOKE ALL ON FUNCTION public.can_book_wish(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_book_wish(bigint, bigint) TO authenticated;
