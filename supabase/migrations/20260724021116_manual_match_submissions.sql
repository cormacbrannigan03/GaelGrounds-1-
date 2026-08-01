-- Backing store for the "manual" provider — today driven from Supabase
-- Studio / an HTTP client with the service_role key; the natural next step
-- if a UI gets built is a form that inserts rows here and nothing else,
-- since the sync pipeline (not the UI) owns turning this into a real match.
create table public.manual_match_submissions (
  id uuid primary key default extensions.uuid_generate_v4(),
  external_ref text not null unique,   -- caller-assigned idempotency key, e.g. 'manual-2026-08-10-dub-kerry'
  sport_code public.sport_code not null,
  competition text not null,
  home_team_name text not null,        -- county name as typed, resolved by the same normalizer as other providers
  away_team_name text not null,
  ground_name text,
  played_at timestamptz not null,
  home_score text,
  away_score text,
  status text not null default 'pending' check (status in ('pending', 'applied', 'error')),
  error_message text,
  submitted_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  applied_at timestamptz
);

comment on table public.manual_match_submissions is
  'Staging table for manually-entered matches. sync-matches picks up status=pending rows, resolves team/ground names, upserts into matches, then marks each row applied or error.';

alter table public.manual_match_submissions enable row level security;
-- No policies — service_role only, matching the rest of the ingestion
-- pipeline. If/when an admin UI ships, it should authenticate with its own
-- service-role-backed API rather than the app's anon key.
