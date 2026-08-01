-- Round-by-round 2021 Leinster SFC, provincial through final. Two matches
-- have a confirmed matchup/winner but no confirmed score: Dublin v Carlow
-- (quarter-final) and Kildare v Louth (semi-final) -- both hit persistent
-- contradictory/wrong-year results (the same Louth-Kildare fixture kept
-- resurfacing 2022 and 2025 scores instead), so rather than guess they are
-- inserted score-less.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Preliminary Round', 'Carlow', 'Wicklow', 'Netwatch Cullen Park', date '2021-06-27', '3-14', '2-15'),
    ('Preliminary Round', 'Louth', 'Westmeath', null, date '2021-06-27', '3-10', '0-10'),
    ('Preliminary Round', 'Laois', 'Wexford', null, date '2021-06-27', '1-11', '0-14'),
    ('Quarter-Final', 'Louth', 'Laois', null, date '2021-07-04', '2-16', '0-17'),
    ('Quarter-Final', 'Meath', 'Longford', null, date '2021-07-04', '4-22', '0-12'),
    ('Quarter-Final', 'Kildare', 'Offaly', 'O''Connor Park', date '2021-07-04', '1-15', '0-13'),
    ('Semi-Final', 'Dublin', 'Meath', 'Croke Park', date '2021-07-18', '2-16', '1-13')
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
  'manual', 'leinster-sfc-2021-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'leinster_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Laois v Wexford preliminary round: level after extra time (1-11 to
-- 0-14 = 14-14), Laois won 4-3 on penalties.
update public.matches m
set winner = 'home'
from public.competitions c
where m.competition_id = c.id and c.code = 'leinster_sfc' and m.season = 2021
  and m.round = 'Preliminary Round' and m.home_score = '1-11';

-- Dublin v Carlow, Quarter-Final: confirmed winner (Dublin), no confirmed
-- score.
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2021, 'Quarter-Final', date '2021-07-04', 'county',
  hct.id, act.id, null,
  c.name, null, null, 'completed', 'home',
  'manual', 'leinster-sfc-2021-quarterfinal-dublin-carlow'
from public.competitions c
join public.counties hc on hc.name = 'Dublin'
join public.counties ac on ac.name = 'Carlow'
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
where c.code = 'leinster_sfc';

-- Kildare v Louth, Semi-Final: confirmed winner (Kildare, since they
-- reached the final), no confirmed score.
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2021, 'Semi-Final', date '2021-07-18', 'county',
  hct.id, act.id, null,
  c.name, null, null, 'completed', 'home',
  'manual', 'leinster-sfc-2021-semifinal-kildare-louth'
from public.competitions c
join public.counties hc on hc.name = 'Kildare'
join public.counties ac on ac.name = 'Louth'
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
where c.code = 'leinster_sfc';

-- Correct the Final's score (row already existed with winner set but null
-- scores): Dublin 0-20 Kildare 1-9.
update public.matches m
set home_score = '0-20', away_score = '1-9'
from public.competitions c
where m.competition_id = c.id and c.code = 'leinster_sfc' and m.season = 2021 and m.round = 'Final';
