-- The DELETE RLS policy added in 20260828160000 wasn't enough on its own:
-- Postgres checks the table-level GRANT before RLS policies ever run, and
-- `authenticated` had only ever been granted INSERT/SELECT/UPDATE on this
-- table, so the achievement-revoke delete kept failing with a plain
-- "permission denied for table user_achievements" -- the DELETE policy
-- existed but was unreachable.
grant delete on public.user_achievements to authenticated;
