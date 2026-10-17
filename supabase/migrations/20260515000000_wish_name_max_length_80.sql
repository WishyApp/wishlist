-- Wish names are limited to 80 characters, like the wish form of the app
-- (wish_form_fields.dart).
--
-- Dated before 20260516000000_capture_remote_drift on purpose: on a project
-- where both are pending, this one runs first, and capture_remote_drift then
-- finds wishs_name_max_length already in place instead of adding it with a
-- limit of 50 that existing wish names exceed.

ALTER TABLE public.wishs DROP CONSTRAINT IF EXISTS wishs_name_max_length;
ALTER TABLE public.wishs
  ADD CONSTRAINT wishs_name_max_length CHECK (char_length(name) <= 80);


-- Verification:
-- SELECT pg_get_constraintdef(oid) FROM pg_constraint
--   WHERE conrelid = 'public.wishs'::regclass AND conname = 'wishs_name_max_length';
--   -> CHECK ((char_length(name) <= 80))
