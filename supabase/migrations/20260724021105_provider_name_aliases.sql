-- Providers report team/ground names as free text ("Dublin", "Dublin GAA",
-- "Dublin Senior Footballers"...). These tables let the normalizer resolve
-- a name to our UUIDs on first sight and remember the mapping — curatable
-- by hand for anything it can't confidently guess.
create table public.provider_team_aliases (
  id uuid primary key default extensions.uuid_generate_v4(),
  provider_code text not null references public.data_providers (code),
  external_name text not null,
  county_team_id uuid not null references public.county_teams (id),
  created_at timestamptz not null default now(),
  unique (provider_code, external_name)
);

create table public.provider_ground_aliases (
  id uuid primary key default extensions.uuid_generate_v4(),
  provider_code text not null references public.data_providers (code),
  external_name text not null,
  ground_id uuid not null references public.grounds (id),
  created_at timestamptz not null default now(),
  unique (provider_code, external_name)
);

alter table public.provider_team_aliases enable row level security;
alter table public.provider_ground_aliases enable row level security;
-- No policies — service_role (the Edge Function) only, same as the rest of
-- the ingestion-internal tables.
