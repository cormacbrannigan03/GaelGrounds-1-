-- Round-by-round 2025 Ulster SFC and Connacht SFC, provincial through final.
-- Same verification bar as the other 2025 provincial seeds. Connacht SFC
-- coverage is partial: London and New York compete in this championship and
-- the schema has no way to represent them as county teams yet, so matches
-- involving either are excluded rather than guessed or dropped silently
-- (flagged to the project owner as an open schema question). Mirrored to
-- disk from the live database for version-control parity; originally
-- applied directly via apply_migration.
with rows(competition_code, round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('ulster_sfc', 'Preliminary Round', 'Donegal', 'Derry', 'MacCumhaill Park', date '2025-04-06', '1-25', '1-15'),
    ('ulster_sfc', 'Quarter-Final', 'Armagh', 'Antrim', 'Corrigan Park', date '2025-04-12', '1-34', '1-23'),
    ('ulster_sfc', 'Quarter-Final', 'Down', 'Fermanagh', 'Brewster Park', date '2025-04-19', '2-23', '0-23'),
    ('ulster_sfc', 'Quarter-Final', 'Donegal', 'Monaghan', 'St Tiernach''s Park', date '2025-04-20', '0-23', '0-21'),
    ('ulster_sfc', 'Quarter-Final', 'Tyrone', 'Cavan', null, null, '1-24', '0-20'),
    ('ulster_sfc', 'Semi-Final', 'Donegal', 'Down', 'St Tiernach''s Park', date '2025-04-27', '1-19', '0-16'),
    ('ulster_sfc', 'Semi-Final', 'Armagh', 'Tyrone', null, null, '0-23', '0-22'),

    ('connacht_sfc', 'Quarter-Final', 'Mayo', 'Sligo', 'MacHale Park', date '2025-04-06', '2-20', '2-17'),
    ('connacht_sfc', 'Semi-Final', 'Galway', 'Roscommon', null, date '2025-04-19', '1-24', '0-18'),
    ('connacht_sfc', 'Semi-Final', 'Leitrim', 'Mayo', null, null, '0-13', '0-20')
)
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2025, r.round, r.match_date, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', r.competition_code || '-2025-' || lower(replace(r.round, ' ', '-')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = r.competition_code
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'football'
left join public.grounds g on g.name = r.ground_name;

-- Finals (Ulster SFC: Donegal 2-23 Armagh 0-28; Connacht SFC: Galway 1-17
-- Mayo 1-15) were already present in the database from an earlier phase of
-- this project; the Connacht final's score was corrected in place during
-- this phase, no insert needed here.
