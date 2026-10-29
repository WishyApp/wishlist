-- Keep a trace of the booked wishes their owner removed, to tell the people
-- who booked them (home card "booked wish removed").
--
-- Why a table of its own: a booking disappears with its wish (foreign key with
-- ON DELETE CASCADE) and nothing else remembers it, so this is the one fact the
-- app cannot recompute afterwards. The table has real columns (what the card
-- shows: wish name, quantity, wishlist name, owner) and is not a generic
-- notifications table with a free-form payload: a future case of the same kind
-- gets its own table.
--
-- Why no soft delete on wishs: every query on wishs would have to filter the
-- removed wishes (see the exclude_archived_wishlists precedent).
--
-- No image is stored: the images of a wish are deleted from the bucket with
-- the wish, the card shows an illustration instead.
--
-- Written only by two BEFORE DELETE triggers, never by clients (no INSERT
-- privilege):
--   - on wishs: a wish deleted by itself (the owner removes it, or
--     delete_or_archive_wishlist deletes the wishes of an archived wishlist);
--   - on wishlists: a wishlist deleted with its wishes.
-- Both are needed because of the foreign key cascade wishlists -> wishs. The
-- cascade deletes the wishlist row first, then runs a DELETE on its wishs: when
-- the trigger of a wish fires, its wishlist is no longer visible (the foreign
-- key actions run in a later command of the same transaction). The trigger of
-- wishs cannot read the wishlist name or its owner then, and does nothing; the
-- trigger of wishlists, fired before its row goes, records all the wishes of
-- the list. The same invisibility is what avoids alerts on an account
-- deletion (auth.users -> profiles -> wishlists -> wishs): when a wishlist is
-- deleted by the cascade, the profile of its owner is already gone, the
-- trigger of wishlists does nothing, and so does the one of wishs. This is
-- verified by supabase-tests/booked_wish_removals.sql.
--
-- Not recorded (rules of record_booked_wish_removals):
--   - a wish the owner marked as received (user_completed_wishs row of the
--     owner): the gift was given;
--   - a booking made by the owner on their own wish.
-- One row per booking (wish_taken_by_user row), with the booked quantity.
--
-- The triggers must never make a deletion fail: they are SECURITY DEFINER (they
-- read the bookings of other users) and swallow any error with a WARNING. An
-- alert lost is better than a wish that cannot be deleted.
--
-- Access: the booker reads their rows and can only set dismissed_at (the card is
-- closed). When the owner or the booker deletes their account, the rows
-- disappear (ON DELETE CASCADE on both profiles). Realtime: the table is
-- published with REPLICA IDENTITY FULL so that the alert shows up without a
-- refresh; the app filters its channel on booker_id and Realtime applies the
-- SELECT policy below to the UPDATEs.

-- 1. Table. wish_id has no foreign key: the wish does not exist any more.
CREATE TABLE IF NOT EXISTS public.booked_wish_removals (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booker_id uuid NOT NULL REFERENCES public.profiles (id) ON UPDATE CASCADE ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES public.profiles (id) ON UPDATE CASCADE ON DELETE CASCADE,
  wish_id bigint NOT NULL,
  wish_name text NOT NULL,
  quantity bigint NOT NULL,
  wishlist_name text NOT NULL,
  removed_at timestamptz NOT NULL DEFAULT now(),
  dismissed_at timestamptz
);

-- Every foreign key has an index (supabase-tests/indexes.sql): the app lists
-- the alerts of the current user by booker_id (the table stays small, a partial
-- index on pending rows would not pay), and the cascade of an account deletion
-- looks rows up by booker_id and owner_id.
CREATE INDEX IF NOT EXISTS booked_wish_removals_booker_id_idx
  ON public.booked_wish_removals (booker_id);
CREATE INDEX IF NOT EXISTS booked_wish_removals_owner_id_idx
  ON public.booked_wish_removals (owner_id);

ALTER TABLE public.booked_wish_removals REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'booked_wish_removals'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.booked_wish_removals;
  END IF;
END $$;

-- 2. Privileges and policies. Nothing for anon. authenticated reads, and
-- updates dismissed_at only. The REVOKE and the GRANTs stay together: a
-- table-level REVOKE also revokes column privileges, so they replay safely.
ALTER TABLE public.booked_wish_removals ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.booked_wish_removals FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.booked_wish_removals TO authenticated;
GRANT UPDATE (dismissed_at) ON public.booked_wish_removals TO authenticated;

DROP POLICY IF EXISTS "Bookers read their removed booked wishes" ON public.booked_wish_removals;
CREATE POLICY "Bookers read their removed booked wishes"
  ON public.booked_wish_removals
  FOR SELECT
  TO authenticated
  USING (booker_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Bookers dismiss their removed booked wishes" ON public.booked_wish_removals;
CREATE POLICY "Bookers dismiss their removed booked wishes"
  ON public.booked_wish_removals
  FOR UPDATE
  TO authenticated
  USING (booker_id = (SELECT auth.uid()))
  WITH CHECK (booker_id = (SELECT auth.uid()));

-- 3. Internal function shared by the two triggers: one row per booking of the
-- given wishes, except the wishes received by the owner and the bookings of the
-- owner. Called by the triggers only (no EXECUTE for anyone else): it writes
-- on behalf of any user. The bookers and the owner must still have a profile,
-- or the foreign keys would refuse the insert.
CREATE OR REPLACE FUNCTION public.record_booked_wish_removals(
  p_wish_ids bigint[],
  p_owner_id uuid,
  p_wishlist_name text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.booked_wish_removals
    (booker_id, owner_id, wish_id, wish_name, quantity, wishlist_name)
  SELECT t.user_id, p_owner_id, w.id, w.name, t.quantity, p_wishlist_name
  FROM public.wishs w
  JOIN public.wish_taken_by_user t ON t.wish_id = w.id
  JOIN public.profiles booker ON booker.id = t.user_id
  WHERE w.id = ANY (p_wish_ids)
    AND t.user_id <> p_owner_id
    AND EXISTS (SELECT 1 FROM public.profiles owner WHERE owner.id = p_owner_id)
    AND NOT EXISTS (
      SELECT 1
      FROM public.user_completed_wishs c
      WHERE c.wish_id = w.id
        AND c.user_id = p_owner_id
    );
END $$;

REVOKE ALL ON FUNCTION public.record_booked_wish_removals(bigint[], uuid, text)
  FROM PUBLIC, anon, authenticated;

-- 4. Trigger on wishs: a wish deleted while its wishlist is still there.
-- During a cascade from wishlists (or from an account) the wishlist is gone
-- and the lookup finds nothing: the trigger of wishlists did the work, or an
-- account deletion must record nothing.
CREATE OR REPLACE FUNCTION public.record_booked_wish_removal_on_wish_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_owner_id uuid;
  v_wishlist_name text;
BEGIN
  SELECT wl.id_owner, wl.name INTO v_owner_id, v_wishlist_name
  FROM public.wishlists wl
  WHERE wl.id = OLD.wishlist_id;

  IF FOUND THEN
    PERFORM public.record_booked_wish_removals(ARRAY[OLD.id], v_owner_id, v_wishlist_name);
  END IF;

  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  -- Never make the deletion fail.
  RAISE WARNING 'record_booked_wish_removal_on_wish_delete failed for wish %: % (%)',
    OLD.id, SQLERRM, SQLSTATE;
  RETURN OLD;
END $$;

REVOKE ALL ON FUNCTION public.record_booked_wish_removal_on_wish_delete()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS record_booked_wish_removal ON public.wishs;
CREATE TRIGGER record_booked_wish_removal
  BEFORE DELETE ON public.wishs
  FOR EACH ROW
  EXECUTE FUNCTION public.record_booked_wish_removal_on_wish_delete();

-- 5. Trigger on wishlists: a wishlist deleted with its wishes. When the owner
-- profile is gone, the deletion comes from an account deletion: nothing to
-- record. The wishes are still there (BEFORE DELETE, and the cascade to wishs
-- has not run yet).
CREATE OR REPLACE FUNCTION public.record_booked_wish_removals_on_wishlist_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = OLD.id_owner) THEN
    PERFORM public.record_booked_wish_removals(
      ARRAY(SELECT w.id FROM public.wishs w WHERE w.wishlist_id = OLD.id),
      OLD.id_owner,
      OLD.name
    );
  END IF;

  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  -- Never make the deletion fail.
  RAISE WARNING 'record_booked_wish_removals_on_wishlist_delete failed for wishlist %: % (%)',
    OLD.id, SQLERRM, SQLSTATE;
  RETURN OLD;
END $$;

REVOKE ALL ON FUNCTION public.record_booked_wish_removals_on_wishlist_delete()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS record_booked_wish_removals ON public.wishlists;
CREATE TRIGGER record_booked_wish_removals
  BEFORE DELETE ON public.wishlists
  FOR EACH ROW
  EXECUTE FUNCTION public.record_booked_wish_removals_on_wishlist_delete();


-- Verification: tests in supabase-tests/booked_wish_removals.sql.
-- Triggers present:
--   SELECT tgname, tgrelid::regclass FROM pg_trigger
--    WHERE tgname IN ('record_booked_wish_removal', 'record_booked_wish_removals');
--   -> one on public.wishs, one on public.wishlists
-- Pending alerts per booker:
--   SELECT booker_id, count(*) FROM public.booked_wish_removals
--    WHERE dismissed_at IS NULL GROUP BY booker_id;
-- Warnings of a trigger that swallowed an error show in the Postgres logs:
--   'record_booked_wish_removal... failed'
