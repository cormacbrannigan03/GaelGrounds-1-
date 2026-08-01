-- Round-by-round 2023 Ulster SFC and Connacht SFC, provincial through
-- final. Connacht SFC is partial: London and New York involved in 3 of the
-- 6 matches (Sligo v London QF, New York v Leitrim QF, Sligo v New York SF)
-- and excluded, same schema-gap policy as other seasons.
with rows(competition_code, round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('ulster_sfc', 'Preliminary Round', 'Armagh', 'Antrim', 'Athletic Grounds', null, '0-20', '1-8'),
    ('ulster_sfc', 'Quarter-Final', 'Armagh', 'Cavan', null, null, '1-14', '0-12'),
    ('ulster_sfc', 'Quarter-Final', 'Derry', 'Fermanagh', 'Brewster Park', null, '3-17', '2-8'),
    ('ulster_sfc', 'Quarter-Final', 'Monaghan', 'Tyrone', 'St Tiernach''s Park', date '2023-04-16', '1-12', '0-14'),
    ('ulster_sfc', 'Quarter-Final', 'Down', 'Donegal', null, date '2023-04-23', '2-13', '1-11'),
    ('ulster_sfc', 'Semi-Final', 'Armagh', 'Down', 'St Tiernach''s Park', null, '4-10', '0-12'),
    ('ulster_sfc', 'Semi-Final', 'Derry', 'Monaghan', 'Healy Park', null, '1-21', '2-10'),

    ('connacht_sfc', 'Quarter-Final', 'Roscommon', 'Mayo', 'MacHale Park', date '2023-04-09', '2-8', '0-10'),
    ('connacht_sfc', 'Semi-Final', 'Galway', 'Roscommon', 'Dr Hyde Park', date '2023-04-23', '1-13', '1-9')
)
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2023, r.round, r.match_date, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', r.competition_code || '-2023-' || lower(replace(r.round, ' ', '-')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = r.competition_code
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Correct the Ulster and Connacht finals' scores (rows already existed
-- with winner set but null scores).
-- Ulster: Armagh 0-18 Derry 1-15 after extra time (18-18 draw), Derry won
-- 3-1 on penalties.
update public.matches m
set home_score = '1-15', away_score = '0-18'
from public.competitions c
where m.competition_id = c.id and c.code = 'ulster_sfc' and m.season = 2023 and m.round = 'Final';

update public.matches m
set home_score = '2-20', away_score = '0-12'
from public.competitions c
where m.competition_id = c.id and c.code = 'connacht_sfc' and m.season = 2023 and m.round = 'Final';
