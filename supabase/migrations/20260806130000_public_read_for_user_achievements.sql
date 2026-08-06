-- Widens user_achievements SELECT visibility to match user_match_attendance's
-- existing "true" policy (see 20260722225206_public_read_for_social_checkins.sql
-- and 20260804185959_add_county_home_achievements_and_friend_visibility, the
-- latter applied live with no corresponding tracked file, restricting
-- visibility to the owner + accepted friends only).
--
-- Needed for the new tier leaderboards (Most Bronze/Silver, Top Gold): they
-- rank every premium user by how many county_home_match/county_away_match
-- achievements they currently hold at each tier, which requires reading
-- every user's unlocked achievements, not just the signed-in user's own and
-- their friends'. Achievements are the same class of public leaderboard
-- data as match/ground counts (both already fully readable by any signed-in
-- user), not private information -- this brings the two tables' visibility
-- back in line with each other.
drop policy if exists "users and friends can view achievements" on public.user_achievements;

create policy "signed-in users can view achievements"
  on public.user_achievements for select
  to authenticated
  using (true);
