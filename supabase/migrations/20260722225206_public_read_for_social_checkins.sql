-- Check-ins are the social core of the app (like Swarm/Futbology): everyone
-- should be able to see who's checked in to a match or ground in real time.
-- Writes stay locked to auth.uid() = user_id via the existing policies.
create policy "match attendance is publicly readable"
  on public.user_match_attendance for select
  using (true);

create policy "ground visits are publicly readable"
  on public.user_visits for select
  using (true);

-- Needed so a checked-in user's display name can be shown to other fans.
create policy "profiles are publicly readable"
  on public.user_profiles for select
  using (true);

-- user_achievements stays private (own-row only) — no change needed there.
