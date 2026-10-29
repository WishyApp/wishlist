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
--   - a wish the owner has received enough of: the gift was given. The owner
--     has received at least as much as the total booked quantity of the wish
--     (user_completed_wishs.quantity of the owner >= sum of the bookings).
--     When the owner received less than the total booked, ALL the bookers are
--     alerted: with a quantity of 3 booked 1 by A and 1 by B, 1 received
--     alerts A and B, 2 received alerts nobody;
--   - a booking made by the owner on their own wish;
--   - a deletion made within 30 days after the owner's birthday or after
--     Christmas (see is_after_party_window): owners tidy their lists after the
--     party without marking the gifts as received, and every booker would get
--     a false "removed" alert for a gift already given. The day is the current
--     day in Europe/Paris, as for user_completed_wishs.completed_at.
-- One row per booking (wish_taken_by_user row), with the booked quantity.
--
-- The triggers are SECURITY DEFINER (they read the bookings of other users) and
-- do not catch errors, like the other triggers of the repo: a deletion they
-- break fails loudly (and shows in Sentry) instead of losing an alert silently.
-- They are written not to fail: every copied column is NOT NULL at its source
-- and both foreign keys of the table are guarded.
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

-- 3. Date helpers, then the internal function shared by the two triggers.

-- Current day in the time zone of the app's users, as for
-- user_completed_wishs.completed_at (20261029100000). A function of its own so
-- that the SQL tests can pin the day: now() is fixed inside a transaction, and
-- a test run in late December would otherwise hit the window below.
CREATE OR REPLACE FUNCTION public.paris_today()
RETURNS date
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT (now() AT TIME ZONE 'Europe/Paris')::date;
$$;

REVOKE ALL ON FUNCTION public.paris_today() FROM PUBLIC, anon, authenticated;

-- Is p_today within 30 days after the birthday of the owner (this year or the
-- previous one: Dec 20 covers up to Jan 19) or after Christmas (Dec 25 to
-- Jan 24 inclusive)? Takes the day as a parameter so that it can be tested on
-- fixed dates. Without a birthday row only Christmas counts. A Feb 29 birthday
-- counts as Feb 28 in a common year.
-- Internal, no EXECUTE for anyone: it reads the birthday of any user,
-- bypassing the policies of profile_birthdays.
CREATE OR REPLACE FUNCTION public.is_after_party_window(p_owner_id uuid, p_today date)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  -- The one place that says how long a party lasts, in days.
  c_window_days CONSTANT integer := 30;
  v_year integer;
  v_party date;
  v_birthday public.profile_birthdays%ROWTYPE;
BEGIN
  SELECT * INTO v_birthday
  FROM public.profile_birthdays b
  WHERE b.profile_id = p_owner_id;

  FOR v_year IN
    SELECT y FROM generate_series(
      extract(year FROM p_today)::integer - 1,
      extract(year FROM p_today)::integer
    ) AS y
  LOOP
    v_party := make_date(v_year, 12, 25);
    IF p_today BETWEEN v_party AND v_party + c_window_days THEN
      RETURN true;
    END IF;

    IF v_birthday.profile_id IS NOT NULL THEN
      v_party := make_date(
        v_year,
        v_birthday.month,
        LEAST(
          v_birthday.day,
          extract(day FROM (make_date(v_year, v_birthday.month, 1)
                            + interval '1 month - 1 day'))::integer
        )
      );
      IF p_today BETWEEN v_party AND v_party + c_window_days THEN
        RETURN true;
      END IF;
    END IF;
  END LOOP;

  RETURN false;
END $$;

REVOKE ALL ON FUNCTION public.is_after_party_window(uuid, date)
  FROM PUBLIC, anon, authenticated;

-- Internal function shared by the two triggers: one row per booking of the
-- given wishes, except the exclusions of the header (received enough, booking of
-- the owner, after-the-party window). Called by the triggers only (no EXECUTE
-- for anyone else): it writes on behalf of any user. The bookers have a profile
-- (foreign key of wish_taken_by_user.user_id) and the owner is checked below.
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
  IF public.is_after_party_window(p_owner_id, public.paris_today()) THEN
    RETURN;
  END IF;

  INSERT INTO public.booked_wish_removals
    (booker_id, owner_id, wish_id, wish_name, quantity, wishlist_name)
  SELECT t.user_id, p_owner_id, w.id, w.name, t.quantity, p_wishlist_name
  FROM public.wishs w
  JOIN public.wish_taken_by_user t ON t.wish_id = w.id
  WHERE w.id = ANY (p_wish_ids)
    AND t.user_id <> p_owner_id
    -- Doubles the guard of the wishlists trigger on purpose (defence in depth):
    -- whatever the caller, no row is written for an owner who is gone.
    AND EXISTS (SELECT 1 FROM public.profiles owner WHERE owner.id = p_owner_id)
    -- The owner received less than the total booked: the bookers are alerted.
    AND (
      SELECT COALESCE(SUM(c.quantity), 0)
      FROM public.user_completed_wishs c
      WHERE c.wish_id = w.id
        AND c.user_id = p_owner_id
    ) < (
      SELECT SUM(b.quantity)
      FROM public.wish_taken_by_user b
      WHERE b.wish_id = w.id
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
