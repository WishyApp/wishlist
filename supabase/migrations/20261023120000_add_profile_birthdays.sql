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

-- 4. Policies add up (OR): fail if a permissive policy other than the ones
-- above exists on the table, for instance one created by hand on a project
-- (CREATE TABLE IF NOT EXISTS keeps a table that already exists, with its
-- policies), and if anon or PUBLIC got a privilege on it.
DO $$
DECLARE
  extra text;
BEGIN
  SELECT string_agg(format('"%s" (%s)', policyname, cmd), ', ')
  INTO extra
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'profile_birthdays'
    AND permissive = 'PERMISSIVE'
    AND policyname NOT IN (
      'Users can read their own and their friends birthdays',
      'Users can insert their own birthday',
      'Users can update their own birthday',
      'Users can delete their own birthday'
    );
  IF extra IS NOT NULL THEN
    RAISE EXCEPTION 'unexpected permissive policy on profile_birthdays: %', extra
      USING HINT = 'Drop it: permissive policies add up and would widen who can read or write birthdays.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_class c, aclexplode(c.relacl) a
    WHERE c.oid = 'public.profile_birthdays'::regclass
      AND a.grantee IN (0, 'anon'::regrole)
  ) OR EXISTS (
    SELECT 1
    FROM pg_attribute t, aclexplode(t.attacl) a
    WHERE t.attrelid = 'public.profile_birthdays'::regclass
      AND t.attnum > 0
      AND a.grantee IN (0, 'anon'::regrole)
  ) THEN
    RAISE EXCEPTION 'anon or PUBLIC still has a privilege on profile_birthdays';
  END IF;
END $$;

-- Tests: supabase-tests/birthday_policies.sql.
