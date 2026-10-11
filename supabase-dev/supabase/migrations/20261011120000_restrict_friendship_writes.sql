-- Restrict writes on friendships: a request is sent by its requester, and
-- only its receiver answers it.

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

-- 2. UPDATE: only the receiver, on the status column only (column
-- privilege), so that requester_id and receiver_id cannot be rewritten.
DROP POLICY IF EXISTS "Enable update for users based on receiver_id" ON public.friendships;
DROP POLICY IF EXISTS "Receivers can answer friendship requests" ON public.friendships;
CREATE POLICY "Receivers can answer friendship requests"
  ON public.friendships
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = receiver_id)
  WITH CHECK ((SELECT auth.uid()) = receiver_id);

REVOKE UPDATE ON TABLE public.friendships FROM anon, authenticated;
GRANT UPDATE (status) ON TABLE public.friendships TO authenticated;


-- Verification:
-- SELECT policyname, cmd, qual, with_check FROM pg_policies
--  WHERE tablename = 'friendships' AND cmd IN ('INSERT', 'UPDATE');
--   -> "Users can send friendship requests", "Receivers can answer friendship requests"
--
-- SELECT privilege_type, column_name FROM information_schema.column_privileges
--  WHERE table_name = 'friendships' AND grantee = 'authenticated'
--    AND privilege_type = 'UPDATE';
--   -> status only
