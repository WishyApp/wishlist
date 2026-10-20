-- Btree indexes on the foreign keys and filter columns that had none.
--
-- Postgres does not index the referencing side of a foreign key. Without these
-- indexes, client filters, RLS policy sub-selects and ON DELETE CASCADE checks
-- scan the whole table. Additive only: no policy, grant or data change.
--
-- Plain CREATE INDEX (not CONCURRENTLY, which cannot run inside the migration
-- transaction): the tables are small, so the brief write lock is acceptable.
--
-- Already covered, so not repeated here:
--   - wish_taken_by_user (user_id): leading column of the primary key
--     (user_id, wish_id).
--   - user_completed_wishs (wish_id), (from_wishlist_id): indexed in
--     20260516000000_capture_remote_drift; (user_id) leads its primary key.
--   - friendships: the unique index friendships_pair_key is on the expressions
--     least(requester_id, receiver_id), greatest(...), so it does not serve
--     filters on requester_id or receiver_id alone.
--
-- Left out: pg_trgm. Profiles are few, so a full scan is cheap, and a trigram
-- index would not be used anyway: search_users filters on the view's JSON
-- expression (v.profile->>'pseudo'), not on profiles.pseudo.


-- 1. wishs (wishlist_id): wishes of a wishlist, RLS joins, cascade from wishlists.

CREATE INDEX IF NOT EXISTS wishs_wishlist_id_idx ON public.wishs (wishlist_id);


-- 2. wishlists (id_owner): wishlists of a user, RLS owner checks, cascade from profiles.
--    Same name and statement as 20261012100000_restrict_private_wishlist_reads so both can merge in any order.

CREATE INDEX IF NOT EXISTS wishlists_id_owner_idx ON public.wishlists (id_owner);


-- 3. friendships (requester_id), (receiver_id): friend and request lists,
--    friendship checks in policies and functions, cascade from profiles.

CREATE INDEX IF NOT EXISTS friendships_requester_id_idx ON public.friendships (requester_id);
CREATE INDEX IF NOT EXISTS friendships_receiver_id_idx ON public.friendships (receiver_id);


-- 4. wish_taken_by_user (wish_id): who booked a wish, cascade from wishs. The
--    primary key (user_id, wish_id) cannot serve a lookup by wish_id alone.

CREATE INDEX IF NOT EXISTS wish_taken_by_user_wish_id_idx ON public.wish_taken_by_user (wish_id);


-- Verification: tests in supabase-tests/indexes.sql.
--
-- SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND indexname LIKE '%\_idx' ORDER BY 1;
--   -> friendships_receiver_id_idx, friendships_requester_id_idx,
--      user_completed_wishs_from_wishlist_id_idx, user_completed_wishs_wish_id_idx,
--      wish_taken_by_user_wish_id_idx, wishlists_id_owner_idx, wishs_wishlist_id_idx
