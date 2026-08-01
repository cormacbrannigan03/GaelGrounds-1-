create table public.data_providers (
  code text primary key,                    -- matches MatchDataProvider.code in the Edge Function registry
  name text not null,
  kind text not null check (kind in ('api', 'csv', 'manual')),
  enabled boolean not null default false,
  run_in_scheduled_sync boolean not null default true, -- false for on-demand-only providers like csv
  priority int not null default 100,         -- lower wins if two providers ever disagree on the same match
  config jsonb not null default '{}'::jsonb, -- non-secret provider config (base URLs, competition filters, etc). Credentials live in Edge Function secrets, never here.
  last_synced_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.data_providers is
  'Registry of match data providers. The Edge Function sync-matches reads the enabled rows and dispatches to the matching provider adapter by code — adding a new provider is: implement MatchDataProvider, insert a row here.';

insert into public.data_providers (code, name, kind, enabled, run_in_scheduled_sync, priority) values
  ('scorebeo', 'ScoreBeo', 'api', false, true, 10),
  ('clubzap', 'ClubZap', 'api', false, true, 20),
  ('csv', 'CSV import', 'csv', true, false, 50),
  ('manual', 'Manual / admin entry', 'manual', true, true, 5);

create table public.data_sync_runs (
  id uuid primary key default extensions.uuid_generate_v4(),
  provider_code text not null references public.data_providers (code),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running' check (status in ('running', 'success', 'error')),
  matches_created int not null default 0,
  matches_updated int not null default 0,
  matches_unchanged int not null default 0,
  matches_skipped int not null default 0,
  error_message text,
  triggered_by text not null default 'cron' check (triggered_by in ('cron', 'manual', 'api'))
);

comment on table public.data_sync_runs is
  'Audit log of every sync-matches invocation, one row per provider per run — the operational visibility into what the ingestion pipeline actually did.';

create index data_sync_runs_provider_started_idx on public.data_sync_runs (provider_code, started_at desc);

alter table public.data_providers enable row level security;
alter table public.data_sync_runs enable row level security;
-- No policies: these are operational/internal tables. Only the Edge
-- Function (using the service_role key, which bypasses RLS) ever touches
-- them — the app's anon key gets zero access, by default-deny.
