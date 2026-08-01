-- Adds the premium-subscription flag used to gate the free-tier limits
-- (match cap, pre-2019 logging, friend requests, leaderboard visibility).
-- Set client-side by the iOS app after StoreKit 2 verifies a purchase —
-- see ios/README.md for the accepted tradeoff this implies.
alter table public.user_profiles
  add column is_premium boolean not null default false,
  add column premium_expires_at timestamptz;
