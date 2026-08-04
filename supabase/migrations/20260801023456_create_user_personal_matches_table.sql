-- Backing table for the manual "Add Match" feature (UserPersonalMatch /
-- UserPersonalMatchInsert in ios/GaelGrounds/Models/UserPersonalMatch.swift,
-- used by AddMatchView.swift and MatchService.fetchPersonalMatches/
-- insertPersonalMatch/deletePersonalMatch). The Swift side of this feature
-- already existed with nothing to back it — this is the missing schema.
create table public.user_personal_matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  home_team text not null,
  away_team text not null,
  competition text,
  round text,
  venue text,
  played_at timestamptz not null,
  home_score text,
  away_score text,
  created_at timestamptz not null default now()
);

alter table public.user_personal_matches enable row level security;

-- Publicly readable, matching the existing "social checkins" pattern for
-- user_match_attendance/user_visits (public read for select in
-- 20260722225206_public_read_for_social_checkins.sql).
create policy "personal matches are publicly readable"
  on public.user_personal_matches for select
  using (true);

create policy "users can delete their own personal matches"
  on public.user_personal_matches for delete
  to authenticated
  using (auth.uid() = user_id);

-- The base owner-scoped insert policy (auth.uid() = user_id) is added
-- here; the free-tier cap/date limits are layered on top as a separate
-- restrictive policy in 20260801023511_free_tier_match_limits.sql.
create policy "users can add their own personal matches"
  on public.user_personal_matches for insert
  to authenticated
  with check (auth.uid() = user_id);
