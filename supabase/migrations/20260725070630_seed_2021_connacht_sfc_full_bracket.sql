-- Round-by-round 2021 Connacht SFC, provincial through final. The one
-- season with no London/New York gap: both withdrew for 2020 and 2021 due
-- to COVID travel restrictions, so all 5 Connacht counties competed
-- directly. Galway had the bye straight to the final. Mayo v Roscommon
-- (semi-final) has a confirmed winner (Mayo) but no confirmed score --
-- every search for it kept resurfacing the (differently-sourced,
-- explicitly dated) 2024 meeting between the same two teams instead.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Quarter-Final', 'Mayo', 'Sligo', 'Markievicz Park', date '2021-06-26', '3-23', '0-12'),
    ('Quarter-Final', 'Roscommon', 'Leitrim', 'Dr Hyde Park', date '2021-06-26', '2-23', '1-9')
)
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2021, r.round, r.match_date, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', 'connacht-sfc-2021-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'connacht_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Mayo v Roscommon, Semi-Final: confirmed winner (Mayo), no confirmed
-- score.
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2021, 'Semi-Final', date '2021-07-04', 'county',
  hct.id, act.id, g.id,
  c.name, null, null, 'completed', 'home',
  'manual', 'connacht-sfc-2021-semifinal-mayo-roscommon'
from public.competitions c
join public.counties hc on hc.name = 'Mayo'
join public.counties ac on ac.name = 'Roscommon'
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = 'Dr Hyde Park'
where c.code = 'connacht_sfc';

-- Correct the Final's score (row already existed with winner set but null
-- scores): Mayo 2-14 Galway 2-8.
update public.matches m
set home_score = '2-14', away_score = '2-8'
from public.competitions c
where m.competition_id = c.id and c.code = 'connacht_sfc' and m.season = 2021 and m.round = 'Final';
