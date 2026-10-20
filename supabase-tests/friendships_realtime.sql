-- Realtime prerequisites of friendships.
--
-- The app filters its Realtime channels on requester_id and receiver_id,
-- DELETE events included (supabase_friendship_stream_repository.dart).
-- Realtime evaluates the filter of a DELETE on the old row, which Postgres only
-- logs in full with REPLICA IDENTITY FULL. Without it, refusing or cancelling a
-- request and removing a friend would stop updating the lists.
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

DO $$
BEGIN
  IF (SELECT relreplident FROM pg_class
      WHERE oid = 'public.friendships'::regclass) <> 'f' THEN
    RAISE EXCEPTION
      'FAIL friendships must be REPLICA IDENTITY FULL (Realtime filters on DELETE)';
  END IF;
  RAISE NOTICE 'ok   friendships is REPLICA IDENTITY FULL';

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'friendships'
  ) THEN
    RAISE EXCEPTION
      'FAIL friendships must be in the supabase_realtime publication';
  END IF;
  RAISE NOTICE 'ok   friendships is published to Realtime';
END $$;

ROLLBACK;
