-- Adds the premium-subscription flag used to gate the free-tier limits
-- (match cap, pre-2019 logging, friend requests, leaderboard visibility).
-- Set client-side by the iOS app after StoreKit 2 verifies a purchase —
-- see ios/README.md for the accepted tradeoff this implies.
--
-- NOTE: this file was written 2026-08-01 but never actually run against the
-- live project until 2026-08-05 -- it existed only in git. That gap broke
-- every client-side read of user_profiles (the Swift UserProfile model
-- expects is_premium/premium_expires_at; missing columns meant a decode
-- error on every fetch, silently swallowed by callers' catch blocks), which
-- is why check-ins stopped showing up in the Profile tab and the
-- Leaderboard stayed empty. Applied for real via the Supabase MCP tools,
-- not `supabase db push`, since this environment has no local Supabase CLI.
alter table public.user_profiles
  add column is_premium boolean not null default false,
  add column premium_expires_at timestamptz;
