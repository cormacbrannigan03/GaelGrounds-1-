-- Round-by-round 2023 Leinster SFC, provincial through final. 2+
-- independent sources per result, arithmetic sanity-checked. Note one
-- reversed-winner correction made during research: a search claimed
-- "Westmeath winning 1-11 to Louth's 2-10" in the quarter-final, which is
-- arithmetically backwards (Louth's 16 > Westmeath's 14); corrected to
-- Louth as the winner, consistent with Louth's confirmed comeback-from-8-
-- down narrative and their run to the final.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Preliminary Round', 'Laois', 'Wexford', null, date '2023-04-09', '2-17', '2-13'),
    ('Preliminary Round', 'Offaly', 'Longford', null, date '2023-04-09', '1-12', '1-11'),
    ('Preliminary Round', 'Wicklow', 'Carlow', null, date '2023-04-09', '2-12', '0-10'),
    ('Quarter-Final', 'Dublin', 'Laois', 'O''Moore Park', date '2023-04-23', '4-30', '2-9'),
    ('Quarter-Final', 'Kildare', 'Wicklow', 'Netwatch Cullen Park', date '2023-04-23', '1-17', '0-10'),
    ('Quarter-Final', 'Louth', 'Westmeath', 'Páirc Tailteann', date '2023-04-23', '2-10', '1-11'),
    ('Quarter-Final', 'Offaly', 'Meath', 'Glenisk O''Connor Park', date '2023-04-23', '1-11', '0-10'),
    ('Semi-Final', 'Dublin', 'Kildare', 'Croke Park', date '2023-04-30', '0-14', '0-12'),
    ('Semi-Final', 'Louth', 'Offaly', 'Croke Park', date '2023-04-30', '0-27', '2-15')
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
  'manual', 'leinster-sfc-2023-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'leinster_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Correct the Final's score (row already existed with winner set but null
-- scores): Dublin 5-21 Louth 0-15.
update public.matches m
set home_score = '5-21', away_score = '0-15'
from public.competitions c
where m.competition_id = c.id and c.code = 'leinster_sfc' and m.season = 2023 and m.round = 'Final';
