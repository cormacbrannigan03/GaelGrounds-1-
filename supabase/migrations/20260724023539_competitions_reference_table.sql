create table public.competitions (
  id uuid primary key default extensions.uuid_generate_v4(),
  code text not null unique,          -- stable machine key, e.g. 'ai_sfc', 'leinster_shc'
  name text not null,                 -- display name
  sport_code public.sport_code not null,
  competition_type text not null check (competition_type in ('league', 'championship', 'provincial', 'tier_cup')),
  tier int not null default 1,        -- 1 = top flight (All-Ireland SFC/SHC, NFL/NHL Div 1, Leinster/Munster/etc finals); higher = lower tier
  province public.province,           -- set only for provincial championships
  created_at timestamptz not null default now()
);

comment on table public.competitions is
  'Reference table for named GAA competitions (leagues, All-Ireland championships, tier cups, provincial championships). matches.competition_id points here; the free-text matches.competition column stays as a display fallback for anything not yet linked.';

insert into public.competitions (code, name, sport_code, competition_type, tier, province) values
  ('nfl', 'National Football League', 'gaelic_football', 'league', 1, null),
  ('nhl', 'National Hurling League', 'hurling', 'league', 1, null),
  ('ai_sfc', 'All-Ireland Senior Football Championship', 'gaelic_football', 'championship', 1, null),
  ('ai_shc', 'All-Ireland Senior Hurling Championship', 'hurling', 'championship', 1, null),
  ('tailteann_cup', 'Tailteann Cup', 'gaelic_football', 'tier_cup', 2, null),
  ('joe_mcdonagh_cup', 'Joe McDonagh Cup', 'hurling', 'tier_cup', 2, null),
  ('christy_ring_cup', 'Christy Ring Cup', 'hurling', 'tier_cup', 3, null),
  ('nickey_rackard_cup', 'Nickey Rackard Cup', 'hurling', 'tier_cup', 4, null),
  ('lory_meagher_cup', 'Lory Meagher Cup', 'hurling', 'tier_cup', 5, null),
  ('leinster_sfc', 'Leinster Senior Football Championship', 'gaelic_football', 'provincial', 1, 'Leinster'),
  ('munster_sfc', 'Munster Senior Football Championship', 'gaelic_football', 'provincial', 1, 'Munster'),
  ('ulster_sfc', 'Ulster Senior Football Championship', 'gaelic_football', 'provincial', 1, 'Ulster'),
  ('connacht_sfc', 'Connacht Senior Football Championship', 'gaelic_football', 'provincial', 1, 'Connacht'),
  ('leinster_shc', 'Leinster Senior Hurling Championship', 'hurling', 'provincial', 1, 'Leinster'),
  ('munster_shc', 'Munster Senior Hurling Championship', 'hurling', 'provincial', 1, 'Munster'),
  -- Kept so the app's existing ladies' football / camogie data (outside this
  -- request's explicit list, but already live in `matches`/`honours`) stays
  -- properly linked rather than orphaned.
  ('ai_lgfa', 'All-Ireland Senior Ladies'' Football Championship', 'ladies_football', 'championship', 1, null),
  ('ai_camogie', 'All-Ireland Senior Camogie Championship', 'camogie', 'championship', 1, null);

alter table public.competitions enable row level security;
create policy "competitions are publicly readable"
  on public.competitions for select
  using (true);

-- Provider name resolution for competitions, mirroring provider_team_aliases
-- / provider_ground_aliases in the sync-matches Edge Function.
create table public.provider_competition_aliases (
  id uuid primary key default extensions.uuid_generate_v4(),
  provider_code text not null references public.data_providers (code),
  external_name text not null,
  competition_id uuid not null references public.competitions (id),
  created_at timestamptz not null default now(),
  unique (provider_code, external_name)
);
alter table public.provider_competition_aliases enable row level security;
-- No policies — service_role (the Edge Function) only, same as the other alias tables.
