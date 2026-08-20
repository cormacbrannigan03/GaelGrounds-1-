-- App Store guideline 5.1.2 (Legal - Privacy - Data Use and Sharing):
-- the app was rejected for uploading a user's display name and stats to
-- a global, other-users-visible Leaderboard without first obtaining
-- explicit consent. Premium status alone was previously the only gate
-- (see LeaderboardView.swift's old entries filter), and premium status is
-- not consent -- a user can subscribe for the match-cap/friends perks
-- without ever intending to be publicly listed.
--
-- Defaults to false for every row, including existing premium users:
-- nobody is grandfathered in, matching Apple's "prior to uploading"
-- requirement literally. The client now requires the user to flip this on
-- explicitly (a dedicated toggle with consent copy) before their profile
-- is included in leaderboard queries.
alter table public.user_profiles
  add column if not exists leaderboard_opt_in boolean not null default false;
