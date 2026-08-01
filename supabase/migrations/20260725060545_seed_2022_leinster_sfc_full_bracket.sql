-- Round-by-round 2022 Leinster SFC, provincial through final. Westmeath v
-- Laois (quarter-final) has a confirmed winner (Westmeath, per the
-- semi-final draw being confirmed as Kildare v Westmeath) but no confirmed
-- score despite repeated searches, several of which surfaced an unrelated
-- 2026 Westmeath-Laois/Kildare-Westmeath rematch instead.
with rows(round, home_county, away_county, ground_name, match_date, throw_in_time, home_score, away_score) as (
  values
    ('Preliminary Round', 'Louth', 'Carlow', 'Páirc Tailteann', date '2022-04-24', null, '5-10', '0-10'),
    ('Preliminary Round', 'Longford', 'Laois', null, date '2022-04-24', null, '1-14', '1-16'),
    ('Preliminary Round', 'Offaly', 'Wexford', null, date '2022-04-24', null, '1-12', '1-15'),
    ('Quarter-Final', 'Dublin', 'Wexford', 'Chadwicks Wexford Park', date '2022-04-30', null, '1-24', '0-4'),
    ('Quarter-Final', 'Meath', 'Wicklow', 'Páirc Tailteann', date '2022-05-01', null, '4-13', '1-12'),
    ('Quarter-Final', 'Kildare', 'Louth', 'O''Connor Park', date '2022-04-30', null, '2-22', '0-12'),
    ('Semi-Final', 'Dublin', 'Meath', 'Croke Park', date '2022-05-15', null, '1-27', '1-14'),
    ('Semi-Final', 'Kildare', 'Westmeath', null, date '2022-05-15', null, '1-21', '2-15')
)
insert into public.matches (
  competition_id, season, round, match_date, throw_in_time, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2022, r.round, r.match_date, r.throw_in_time::time, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', 'leinster-sfc-2022-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'leinster_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Westmeath v Laois, Quarter-Final: confirmed winner (Westmeath), no
-- confirmed score.
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2022, 'Quarter-Final', date '2022-05-01', 'county',
  hct.id, act.id, null,
  c.name, null, null, 'completed', 'home',
  'manual', 'leinster-sfc-2022-quarterfinal-westmeath-laois'
from public.competitions c
join public.counties hc on hc.name = 'Westmeath'
join public.counties ac on ac.name = 'Laois'
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
where c.code = 'leinster_sfc';

-- Correct the Final's score (row already existed with winner set but null
-- scores): Dublin 0-20 Kildare 1-9.
update public.matches m
set home_score = '0-20', away_score = '1-9'
from public.competitions c
where m.competition_id = c.id and c.code = 'leinster_sfc' and m.season = 2022 and m.round = 'Final';
