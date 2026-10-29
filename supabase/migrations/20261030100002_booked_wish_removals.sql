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
--     Christmas (see after_party_date), for the bookings made BEFORE that party:
--     owners tidy their lists after the party without marking the gifts as
--     received, and every booker who gave would get a false "removed" alert. A
--     booking made after the party (or on its day) cannot be a gift already
--     given and is alerted; a booking without date counts as before. Days are
--     Paris days. When two parties cover the day (a Dec 20 birthday and
--     Christmas) the later one counts, so more bookings count as "before";
--   - a wish of a list whose event is over: archived (deleted_at), closed
--     (is_closed) or whose end_date is before today (Paris day), same reasoning
--     as the party window. A list ending today is still active. is_closed and
--     end_date are not set by the app today, so in practice only archived
--     lists are concerned now.
-- One row per booking (wish_taken_by_user row), with the booked quantity.
--
-- owner_pseudo is copied from profiles.pseudo at deletion time, like wish_name
-- and wishlist_name: a booker who is not a friend of the owner could read the
-- owner's profile only through the booking, which goes away with the wish
-- (can_read_profile), and the card must still show the name. profiles.pseudo
-- is nullable: a missing pseudo is copied as an empty string.
--
-- The triggers are SECURITY DEFINER (they read the bookings of other users) and
-- do not catch errors, like the other triggers of the repo: a deletion they
-- break fails loudly (and shows in Sentry) instead of losing an alert silently.
-- They are written not to fail: every copied column is NOT NULL at its source
-- (a missing pseudo is coalesced) and both foreign keys of the table are
-- guarded.
--
-- Access: the booker reads their rows and closes an alert through
-- dismiss_booked_wish_removal (server time, own row only; no UPDATE
-- privilege). When the owner or the booker deletes their account, the rows
-- disappear (ON DELETE CASCADE on both profiles). Realtime: the table is
-- published with REPLICA IDENTITY FULL so that the alert shows up without a
-- refresh; the app filters its channel on booker_id and Realtime applies the
-- SELECT policy below to the UPDATEs.

-- 1. Table. wish_id has no foreign key: the wish does not exist any more.
CREATE TABLE IF NOT EXISTS public.booked_wish_removals (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booker_id uuid NOT NULL REFERENCES public.profiles (id) ON UPDATE CASCADE ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES public.profiles (id) ON UPDATE CASCADE ON DELETE CASCADE,
  owner_pseudo text NOT NULL,
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

-- 2. Privileges and policies. Nothing for anon. authenticated reads; the only
-- write is dismiss_booked_wish_removal (below), so no UPDATE privilege and no
-- UPDATE policy. Explicit REVOKE so that a replay also removes what an earlier
-- version of this migration granted.
ALTER TABLE public.booked_wish_removals ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.booked_wish_removals FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.booked_wish_removals TO authenticated;

DROP POLICY IF EXISTS "Bookers read their removed booked wishes" ON public.booked_wish_removals;
CREATE POLICY "Bookers read their removed booked wishes"
  ON public.booked_wish_removals
  FOR SELECT
  TO authenticated
  USING (booker_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Bookers dismiss their removed booked wishes" ON public.booked_wish_removals;

-- Closes an alert of the caller. The time is the server's, and the client
-- cannot write anything else (nor reopen an alert). An alert already closed
-- keeps its first dismissed_at. The row of another user is not touched: the
-- UPDATE finds nothing.
CREATE OR REPLACE FUNCTION public.dismiss_booked_wish_removal(p_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'insufficient_privilege';
  END IF;

  UPDATE public.booked_wish_removals r
  SET dismissed_at = now()
  WHERE r.id = p_id
    AND r.booker_id = (SELECT auth.uid())
    AND r.dismissed_at IS NULL;
END $$;

REVOKE ALL ON FUNCTION public.dismiss_booked_wish_removal(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dismiss_booked_wish_removal(bigint) TO authenticated;

-- 3. Date helpers, then the internal function shared by the two triggers.

-- Current day in the time zone of the app's users: the one definition, also the
-- default of user_completed_wishs.completed_at (below). A function of its own so
-- that the SQL tests can pin the day: now() is fixed inside a transaction, and
-- a test run in late December would otherwise hit the window below.
-- A column default runs with the privileges of the inserting role: the owner
-- marking a wish as received is authenticated, so it must be able to execute
-- the function. It only returns the current date, nothing to protect.
CREATE OR REPLACE FUNCTION public.paris_today()
RETURNS date
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT (now() AT TIME ZONE 'Europe/Paris')::date;
$$;

REVOKE ALL ON FUNCTION public.paris_today() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.paris_today() TO authenticated;

-- Same value as the default of 20261029100000, now defined in one place.
-- Replayable: SET DEFAULT overwrites.
ALTER TABLE public.user_completed_wishs
  ALTER COLUMN completed_at SET DEFAULT public.paris_today();

-- Date of the party whose 30 days after cover p_today, or NULL when p_today is
-- outside any window: after the owner's birthday (this year or the previous
-- one: Dec 20 covers up to Jan 19) or after Christmas (Dec 25 to Jan 24
-- inclusive). When two parties cover the day, the later date is returned.
-- Takes the day as a parameter so that it can be tested on fixed dates. Without
-- a birthday row only Christmas counts. A Feb 29 birthday counts as Feb 28 in
-- a common year.
-- Internal, no EXECUTE for anyone: it reads the birthday of any user,
-- bypassing the policies of profile_birthdays.
CREATE OR REPLACE FUNCTION public.after_party_date(p_owner_id uuid, p_today date)
RETURNS date
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
  v_found date := NULL;
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
      v_found := GREATEST(v_found, v_party);
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
        v_found := GREATEST(v_found, v_party);
      END IF;
    END IF;
  END LOOP;

  RETURN v_found;
END $$;

REVOKE ALL ON FUNCTION public.after_party_date(uuid, date)
  FROM PUBLIC, anon, authenticated;

-- Internal function shared by the two triggers: one row per booking of the
-- given wishes of the wishlist p_wishlist_id (it reads the wishlist: name,
-- owner, state), except the exclusions of the header. Called by the triggers
-- only (no EXECUTE for anyone else): it writes on behalf of any user. The
-- bookers have a profile (foreign key of wish_taken_by_user.user_id) and the
-- owner is checked below.
CREATE OR REPLACE FUNCTION public.record_booked_wish_removals(
  p_wish_ids bigint[],
  p_wishlist_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_wishlist public.wishlists%ROWTYPE;
  v_today date;
  v_party date;
BEGIN
  -- Most deletions concern wishes nobody booked: nothing else to compute.
  IF NOT EXISTS (
    SELECT 1 FROM public.wish_taken_by_user t WHERE t.wish_id = ANY (p_wish_ids)
  ) THEN
    RETURN;
  END IF;

  SELECT * INTO v_wishlist
  FROM public.wishlists wl
  WHERE wl.id = p_wishlist_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_today := public.paris_today();

  -- The event of the list is over.
  IF v_wishlist.deleted_at IS NOT NULL
     OR v_wishlist.is_closed
     OR (v_wishlist.end_date AT TIME ZONE 'Europe/Paris')::date < v_today THEN
    RETURN;
  END IF;

  v_party := public.after_party_date(v_wishlist.id_owner, v_today);

  INSERT INTO public.booked_wish_removals
    (booker_id, owner_id, owner_pseudo, wish_id, wish_name, quantity, wishlist_name)
  SELECT t.user_id, v_wishlist.id_owner, COALESCE(owner.pseudo, ''), w.id, w.name,
         t.quantity, v_wishlist.name
  FROM public.wishs w
  JOIN public.wish_taken_by_user t ON t.wish_id = w.id
  -- Doubles the guard of the wishlists trigger on purpose (defence in depth):
  -- whatever the caller, no row is written for an owner who is gone.
  JOIN public.profiles owner ON owner.id = v_wishlist.id_owner
  WHERE w.id = ANY (p_wish_ids)
    AND t.user_id <> v_wishlist.id_owner
    -- Within the after-the-party window only the bookings made before the party
    -- are dropped. A booking without date counts as before.
    AND (
      v_party IS NULL
      OR t.created_at IS NOT NULL
         AND (t.created_at AT TIME ZONE 'Europe/Paris')::date >= v_party
    )
    -- The owner received less than the total booked: the bookers are alerted.
    AND (
      SELECT COALESCE(SUM(c.quantity), 0)
      FROM public.user_completed_wishs c
      WHERE c.wish_id = w.id
        AND c.user_id = v_wishlist.id_owner
    ) < (
      SELECT SUM(b.quantity)
      FROM public.wish_taken_by_user b
      WHERE b.wish_id = w.id
    );
END $$;

REVOKE ALL ON FUNCTION public.record_booked_wish_removals(bigint[], bigint)
  FROM PUBLIC, anon, authenticated;

-- 4. Trigger on wishs: a wish deleted while its wishlist is still there.
-- During a cascade from wishlists (or from an account) the wishlist is gone
-- and the shared function finds nothing: the trigger of wishlists did the work, or an
-- account deletion must record nothing.
CREATE OR REPLACE FUNCTION public.record_booked_wish_removal_on_wish_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Short-circuit: nobody booked this wish.
  IF NOT EXISTS (
    SELECT 1 FROM public.wish_taken_by_user t WHERE t.wish_id = OLD.id
  ) THEN
    RETURN OLD;
  END IF;

  -- The shared function does nothing when the wishlist is not visible (cascade).
  PERFORM public.record_booked_wish_removals(ARRAY[OLD.id], OLD.wishlist_id);

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
      OLD.id
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
