-- Round-by-round 2024 Ulster SFC and Connacht SFC, provincial through
-- final. Same verification bar as elsewhere in this project: 2+
-- independent sources, arithmetic sanity-checked, explicit year-dated
-- sources trusted over undated ones given repeated cross-year
-- contamination discovered during this research (results from other
-- seasons surfacing for same-fixture recency-biased queries). Connacht SFC
-- is partial: Galway v London and Mayo v New York are excluded, same as
-- 2025, since the schema has no way to represent London/New York as county
-- teams.
with rows(competition_code, round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('ulster_sfc', 'Quarter-Final', 'Donegal', 'Derry', 'Celtic Park', date '2024-04-20', '4-11', '0-17'),
    ('ulster_sfc', 'Quarter-Final', 'Tyrone', 'Cavan', 'Kingspan Breffni Park', null, '1-23', '3-16'),
    ('ulster_sfc', 'Quarter-Final', 'Armagh', 'Fermanagh', 'Brewster Park', null, '3-11', '0-9'),
    ('ulster_sfc', 'Quarter-Final', 'Down', 'Antrim', 'Páirc Esler', null, '0-13', '0-9'),
    ('ulster_sfc', 'Semi-Final', 'Donegal', 'Tyrone', 'Celtic Park', date '2024-04-27', '0-18', '0-16'),
    ('ulster_sfc', 'Semi-Final', 'Armagh', 'Down', null, date '2024-04-27', '0-13', '2-6'),

    ('connacht_sfc', 'Quarter-Final', 'Sligo', 'Leitrim', 'Páirc Seán Mac Diarmada', date '2024-04-07', '0-15', '0-6'),
    ('connacht_sfc', 'Semi-Final', 'Galway', 'Sligo', null, date '2024-04-20', '1-13', '0-14'),
    ('connacht_sfc', 'Semi-Final', 'Mayo', 'Roscommon', 'Dr Hyde Park', date '2024-04-21', '1-15', '0-13')
)
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2024, r.round, r.match_date, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', r.competition_code || '-2024-' || lower(replace(r.round, ' ', '-')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = r.competition_code
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Correct the Ulster and Connacht finals' scores now that they're
-- confirmed (rows already existed with winner set but null scores).
update public.matches m
set home_score = '2-23', away_score = '0-28'
from public.competitions c
where m.competition_id = c.id and c.code = 'ulster_sfc' and m.season = 2024 and m.round = 'Final';

update public.matches m
set home_score = '0-16', away_score = '0-15'
from public.competitions c
where m.competition_id = c.id and c.code = 'connacht_sfc' and m.season = 2024 and m.round = 'Final';
