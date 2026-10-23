-- Store an optional birthday (day and month, no year) per user, readable by
-- its owner and by their accepted friends only.
--
-- It is a table of its own, not a column of profiles: profiles is readable by
-- the users who share a pending friendship with the owner, and by the owners
-- of public wishlists (see can_read_profile). A birthday must not follow those
-- rules, a stranger who sent a friend request must not get it.
--
-- Without a year, February 29 is a valid date: the CHECK only rejects days
-- that exist in no year.

-- 1. Shared rule. SECURITY DEFINER with a pinned search_path: it reads
-- friendships without going through its policies. It only answers about the
-- current user (auth.uid()). A pending friendship does not count, whichever
-- side sent the request.
CREATE OR REPLACE FUNCTION public.can_read_birthday(p_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p_profile_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.friendships f
      WHERE least(f.requester_id, f.receiver_id) = least((SELECT auth.uid()), p_profile_id)
        AND greatest(f.requester_id, f.receiver_id) = greatest((SELECT auth.uid()), p_profile_id)
        AND f.status = 'accepted'
    );
$$;

REVOKE ALL ON FUNCTION public.can_read_birthday(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_read_birthday(uuid) TO authenticated;

-- 2. Table. One row per user, deleted with the profile (account deletion).
CREATE TABLE IF NOT EXISTS public.profile_birthdays (
  profile_id uuid PRIMARY KEY REFERENCES public.profiles (id) ON UPDATE CASCADE ON DELETE CASCADE,
  month smallint NOT NULL,
  day smallint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT profile_birthdays_valid_date CHECK (
    month BETWEEN 1 AND 12
    AND day >= 1
    AND day <= CASE
      WHEN month = 2 THEN 29
      WHEN month IN (4, 6, 9, 11) THEN 30
      ELSE 31
    END
  )
);

-- Nothing for anon; authenticated reads and writes under the policies below.
-- Explicit, so that it does not depend on the default privileges.
REVOKE ALL ON public.profile_birthdays FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profile_birthdays TO authenticated;

-- 3. Row level security. Writes are limited to the own row, and the WITH CHECK
-- keeps an update from handing a row to someone else.
ALTER TABLE public.profile_birthdays ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own and their friends birthdays" ON public.profile_birthdays;
CREATE POLICY "Users can read their own and their friends birthdays"
  ON public.profile_birthdays
  FOR SELECT
  TO authenticated
  USING (public.can_read_birthday(profile_id));

DROP POLICY IF EXISTS "Users can insert their own birthday" ON public.profile_birthdays;
CREATE POLICY "Users can insert their own birthday"
  ON public.profile_birthdays
  FOR INSERT
  TO authenticated
  WITH CHECK (profile_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can update their own birthday" ON public.profile_birthdays;
CREATE POLICY "Users can update their own birthday"
  ON public.profile_birthdays
  FOR UPDATE
  TO authenticated
  USING (profile_id = (SELECT auth.uid()))
  WITH CHECK (profile_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can delete their own birthday" ON public.profile_birthdays;
CREATE POLICY "Users can delete their own birthday"
  ON public.profile_birthdays
  FOR DELETE
  TO authenticated
  USING (profile_id = (SELECT auth.uid()));

-- Tests: supabase-tests/birthday_policies.sql.
