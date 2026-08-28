-- user_achievements had INSERT/SELECT/UPDATE policies but no DELETE policy,
-- so useAchievements.ts's revoke path (`.delete().in('id', revokedRowIds)`)
-- was being silently blocked by RLS -- it returned no error, just 0 rows
-- affected, so achievements that stopped qualifying (e.g. after undoing the
-- one check-in that had put a county over a threshold) never actually got
-- removed. This closes that gap.
create policy "users can delete their own achievements"
  on public.user_achievements
  for delete
  to authenticated
  using (auth.uid() = user_id);
