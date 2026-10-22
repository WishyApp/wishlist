-- Minimum and recommended app version per platform, read by the app before
-- sign in to block a version that is too old (min_version) or suggest an
-- update (recommended_version).
--
-- The table is not exposed: RLS on, no privilege for PUBLIC, anon and
-- authenticated. The app reads it through get_app_version_policy, a SECURITY
-- DEFINER function callable by anon (like get_email_by_pseudo, see
-- 20261012110000_restrict_anon_privileges): the check runs on the sign in
-- screen, before any session exists.
--
-- Initial values 0.0.0 block and suggest nothing. To raise them, from the SQL
-- editor of the project (a value change, not a schema change):
--   UPDATE public.app_versions SET min_version = '0.3.0' WHERE platform = 'ios';
-- update_url is the store page opened by the update button. NULL (store links
-- not public yet): the screen only asks to update from TestFlight / Play Store.

CREATE TABLE IF NOT EXISTS public.app_versions (
  platform text PRIMARY KEY,
  min_version text NOT NULL DEFAULT '0.0.0',
  recommended_version text NOT NULL DEFAULT '0.0.0',
  update_url text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'app_versions_platform_check'
      AND conrelid = 'public.app_versions'::regclass
  ) THEN
    ALTER TABLE public.app_versions
      ADD CONSTRAINT app_versions_platform_check CHECK (platform IN ('ios', 'android'));
  END IF;
END $$;

ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_versions FROM PUBLIC, anon, authenticated;

-- Existing rows (values already raised) are left as they are.
INSERT INTO public.app_versions (platform) VALUES ('ios'), ('android')
ON CONFLICT (platform) DO NOTHING;

CREATE OR REPLACE FUNCTION public.get_app_version_policy(p_platform text)
  RETURNS TABLE (min_version text, recommended_version text, update_url text)
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path = ''
AS $$
  SELECT v.min_version, v.recommended_version, v.update_url
    FROM public.app_versions v
   WHERE v.platform = p_platform;
$$;

REVOKE ALL ON FUNCTION public.get_app_version_policy(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_app_version_policy(text) TO anon, authenticated;
