-- Newly created tables in the public schema pick up Supabase's default
-- broad grants to anon/authenticated automatically. RLS already blocks
-- anon in practice (no anon policy exists on match_reports), but this
-- project explicitly revokes unused grants on user-data tables as defense
-- in depth (see user_profiles, hardened in an earlier, untracked pass).
-- Matching that posture here now that match_reports actually exists live.
revoke all on public.match_reports from anon;
revoke delete, update on public.match_reports from authenticated;
