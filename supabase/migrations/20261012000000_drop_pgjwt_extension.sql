-- Supabase requires removing pgjwt (deprecated) before upgrading to
-- Postgres 17.11, and nothing in the schema uses it. It was already removed
-- from the dashboard on both projects, so this keeps the migrations in line
-- with the databases.
--
-- Verification:
--   SELECT extname FROM pg_extension WHERE extname = 'pgjwt'; -- no row

DROP EXTENSION IF EXISTS pgjwt;
