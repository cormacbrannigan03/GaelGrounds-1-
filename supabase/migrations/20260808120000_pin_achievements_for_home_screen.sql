-- Lets users choose which of their unlocked achievements show in the
-- "Achievements" preview on the profile/home screen, instead of it always
-- being the 4 most recently unlocked. Tapping an achievement in the
-- Unlocked tab stars/unstars it (see ProfileView.togglePinned); the preview
-- shows starred achievements when any exist, falling back to most-recent
-- otherwise.
alter table public.user_achievements
  add column if not exists pinned boolean not null default false;

-- No UPDATE policy existed on this table at all (only insert + public
-- select) -- needed now so a user can toggle pinned on their own rows.
create policy "users can update their own achievements"
  on public.user_achievements for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
