-- Restrict writes on friendships: a request is sent by its requester, only
-- its receiver accepts it, and a pair of users has a single row.

-- 1. INSERT: a pending request, sent in the current user's name, to someone
-- else.
DROP POLICY IF EXISTS "Enable insert for users based on user_id" ON public.friendships;
DROP POLICY IF EXISTS "Users can send friendship requests" ON public.friendships;
CREATE POLICY "Users can send friendship requests"
  ON public.friendships
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = requester_id
    AND requester_id <> receiver_id
    AND status = 'pending'
  );

-- 2. UPDATE: only the receiver, from pending to accepted, the one change the
-- app makes (other statuses are not read by the app). Declining, cancelling
-- and removing go through DELETE.
DROP POLICY IF EXISTS "Enable update for users based on receiver_id" ON public.friendships;
DROP POLICY IF EXISTS "Receivers can answer friendship requests" ON public.friendships;
DROP POLICY IF EXISTS "Receivers can accept friendship requests" ON public.friendships;
CREATE POLICY "Receivers can accept friendship requests"
  ON public.friendships
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = receiver_id AND status = 'pending')
  WITH CHECK ((SELECT auth.uid()) = receiver_id AND status = 'accepted');

-- Only status is writable by clients (column privilege). The trigger below
-- also rejects any change of requester_id or receiver_id, should the table
-- privileges be granted again, and keeps updated_at current.
REVOKE UPDATE ON TABLE public.friendships FROM anon, authenticated;
GRANT UPDATE (status) ON TABLE public.friendships TO authenticated;

CREATE OR REPLACE FUNCTION public.friendships_before_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.requester_id IS DISTINCT FROM OLD.requester_id
    OR NEW.receiver_id IS DISTINCT FROM OLD.receiver_id THEN
    RAISE EXCEPTION 'requester_id and receiver_id of a friendship cannot change'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS friendships_before_update ON public.friendships;
CREATE TRIGGER friendships_before_update
  BEFORE UPDATE ON public.friendships
  FOR EACH ROW
  EXECUTE FUNCTION public.friendships_before_update();


-- 3. One row per pair of users, whichever sent the request. Duplicates are
-- removed first, keeping an accepted row over a pending one, then the oldest.
DELETE FROM public.friendships f
USING (
  SELECT id,
    row_number() OVER (
      PARTITION BY least(requester_id, receiver_id), greatest(requester_id, receiver_id)
      ORDER BY (status = 'accepted') DESC, created_at, id
    ) AS rank
  FROM public.friendships
) ranked
WHERE f.id = ranked.id
  AND ranked.rank > 1;

CREATE UNIQUE INDEX IF NOT EXISTS friendships_pair_key
  ON public.friendships (least(requester_id, receiver_id), greatest(requester_id, receiver_id));


-- Verification: tests in supabase-tests/friendship_policies.sql.
--
-- SELECT least(requester_id, receiver_id), greatest(requester_id, receiver_id), count(*)
--   FROM public.friendships GROUP BY 1, 2 HAVING count(*) > 1;
--   -> no rows
