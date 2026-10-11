-- Capture schema changes made on the remote projects outside of migrations.
-- Idempotent: safe to run on a project where some or all of these objects
-- already exist (see docs/supabase-migrations.md).

-- 1. Max length constraints (present on dev and prod)

DO $$
DECLARE
  c record;
BEGIN
  FOR c IN
    SELECT * FROM (VALUES
      ('profiles',  'profiles_pseudo_max_length',     '(pseudo IS NULL) OR (char_length(pseudo) <= 50)'),
      ('profiles',  'profiles_avatar_url_max_length', '(avatar_url IS NULL) OR (char_length(avatar_url) <= 500)'),
      ('wishlists', 'wishlists_name_max_length',      'char_length(name) <= 50'),
      ('wishlists', 'wishlists_color_max_length',     '(color IS NULL) OR (char_length(color) <= 10)'),
      ('wishlists', 'wishlists_icon_url_max_length',  '(icon_url IS NULL) OR (char_length(icon_url) <= 500)'),
      ('wishs',     'wishs_name_max_length',          'char_length(name) <= 50'),
      ('wishs',     'wishs_description_max_length',   'char_length(description) <= 500'),
      ('wishs',     'wishs_link_url_max_length',      '(link_url IS NULL) OR (char_length(link_url) <= 500)'),
      ('wishs',     'wishs_icon_url_max_length',      '(icon_url IS NULL) OR (char_length(icon_url) <= 500)')
    ) AS t(table_name, constraint_name, check_expression)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = c.constraint_name
        AND conrelid = format('public.%I', c.table_name)::regclass
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.%I ADD CONSTRAINT %I CHECK (%s)',
        c.table_name, c.constraint_name, c.check_expression
      );
    END IF;
  END LOOP;
END $$;


-- 2. user_completed_wishs (created on dev only, required by later migrations)

CREATE TABLE IF NOT EXISTS public.user_completed_wishs (
  user_id uuid NOT NULL,
  wish_id bigint NOT NULL,
  from_wishlist_id bigint NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_completed_wishs_pkey PRIMARY KEY (user_id, wish_id),
  CONSTRAINT user_completed_wishs_user_id_fkey FOREIGN KEY (user_id)
    REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT user_completed_wishs_wish_id_fkey FOREIGN KEY (wish_id)
    REFERENCES public.wishs(id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT user_completed_wishs_from_wishlist_id_fkey FOREIGN KEY (from_wishlist_id)
    REFERENCES public.wishlists(id) ON UPDATE CASCADE ON DELETE CASCADE
);

-- The primary key (user_id, wish_id) does not serve lookups by wish_id or
-- from_wishlist_id alone: FK cascades from wishs and wishlists, and the
-- wishlist archiving function, filter on them.
CREATE INDEX IF NOT EXISTS user_completed_wishs_wish_id_idx
  ON public.user_completed_wishs (wish_id);
CREATE INDEX IF NOT EXISTS user_completed_wishs_from_wishlist_id_idx
  ON public.user_completed_wishs (from_wishlist_id);

ALTER TABLE public.user_completed_wishs ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_completed_wishs REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'user_completed_wishs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.user_completed_wishs;
  END IF;
END $$;

-- Policies are recreated so that every project ends up with the same rules,
-- under names that describe them. The DROP on the old names cleans up dev.
DROP POLICY IF EXISTS "Enable read access for authenticated users only" ON public.user_completed_wishs;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.user_completed_wishs;
DROP POLICY IF EXISTS "Enable update for authenticated users based on user_id" ON public.user_completed_wishs;
DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON public.user_completed_wishs;

DROP POLICY IF EXISTS "Authenticated users can read completed wishes" ON public.user_completed_wishs;
CREATE POLICY "Authenticated users can read completed wishes"
  ON public.user_completed_wishs
  FOR SELECT
  TO authenticated
  USING (true);

-- A wish is completed by the owner of its wishlist: the row must point to one
-- of the current user's wishes, through the wishlist that holds it. Otherwise
-- anyone could attach a completion to another user's wishlist and turn its
-- deletion into an archive.
DROP POLICY IF EXISTS "Users can complete their own wishes" ON public.user_completed_wishs;
CREATE POLICY "Users can complete their own wishes"
  ON public.user_completed_wishs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND EXISTS (
      SELECT 1
      FROM public.wishs w
      JOIN public.wishlists wl ON wl.id = w.wishlist_id
      WHERE w.id = user_completed_wishs.wish_id
        AND w.wishlist_id = user_completed_wishs.from_wishlist_id
        AND wl.id_owner = (SELECT auth.uid())
    )
  );

-- Updates are limited to the user's own rows here, and to the columns the app
-- changes through column privileges: wish_id and from_wishlist_id must not be
-- rewritten after the insert check. UPDATE is revoked as a whole, the
-- migration adding the quantity column grants UPDATE (quantity) back.
DROP POLICY IF EXISTS "Users can update their own completed wishes" ON public.user_completed_wishs;
CREATE POLICY "Users can update their own completed wishes"
  ON public.user_completed_wishs
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

REVOKE UPDATE ON public.user_completed_wishs FROM anon, authenticated;

DROP POLICY IF EXISTS "Users can delete their own completed wishes" ON public.user_completed_wishs;
CREATE POLICY "Users can delete their own completed wishes"
  ON public.user_completed_wishs
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);


-- 3. Objects created on dev only and not used by the app

-- Superseded by wishs_name_max_length (50).
ALTER TABLE public.wishs DROP CONSTRAINT IF EXISTS wishs_name_check;

DROP FUNCTION IF EXISTS public.batch_update_wishlists_order(jsonb);


-- Verification:
-- supabase db diff --linked --schema public
--   -> no output for the objects above
--
-- SELECT conrelid::regclass, conname FROM pg_constraint
--  WHERE conname LIKE '%max_length' ORDER BY 1, 2;
--   -> 9 rows
--
-- SELECT policyname, cmd, qual, with_check FROM pg_policies
--  WHERE tablename = 'user_completed_wishs';
--   -> 4 rows, named "... completed wishes" / "Users can complete their own wishes"
--
-- SELECT indexname FROM pg_indexes WHERE tablename = 'user_completed_wishs';
--   -> user_completed_wishs_pkey, _wish_id_idx, _from_wishlist_id_idx
