-- Round-by-round 2024 Leinster SFC, provincial through final. Same
-- verification bar as 2025/2024 Munster: 2+ independent sources per result
-- where possible, arithmetic sanity-checked via gaa_score_total(). The
-- Louth v Wexford quarter-final score could not be pinned down beyond
-- "Louth won, Sam Mulroy scored 2-04 in the closing quarter" despite
-- repeated searches, so it is inserted with a confirmed matchup/winner but
-- null score rather than guessed.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Preliminary Round', 'Wexford', 'Carlow', null, date '2024-04-07', '4-19', '0-8'),
    ('Preliminary Round', 'Meath', 'Longford', null, date '2024-04-07', '3-19', '3-12'),
    ('Preliminary Round', 'Wicklow', 'Westmeath', null, date '2024-04-07', '2-9', '1-11'),
    ('Quarter-Final', 'Laois', 'Offaly', null, date '2024-04-13', '1-8', '2-13'),
    ('Quarter-Final', 'Kildare', 'Wicklow', null, date '2024-04-13', '0-16', '1-12'),
    ('Quarter-Final', 'Dublin', 'Meath', 'Croke Park', date '2024-04-14', '3-19', '0-12'),
    ('Semi-Final', 'Dublin', 'Offaly', 'Croke Park', date '2024-04-28', '3-22', '0-11'),
    ('Semi-Final', 'Louth', 'Kildare', 'Croke Park', date '2024-04-28', '0-17', '0-13')
),
wexford_qf as (
  insert into public.matches (
    competition_id, season, round, match_date, match_type,
    home_county_team_id, away_county_team_id, ground_id,
    competition, home_score, away_score, status, winner,
    source_provider, source_ref
  )
  select
    c.id, 2024, 'Quarter-Final', date '2024-04-14', 'county',
    hct.id, act.id, null,
    c.name, null, null, 'completed', 'home',
    'manual', 'leinster-sfc-2024-quarterfinal-louth-wexford'
  from public.competitions c
  join public.counties hc on hc.name = 'Louth'
  join public.counties ac on ac.name = 'Wexford'
  join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
  join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
  where c.code = 'leinster_sfc'
  returning 1
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
  'manual', 'leinster-sfc-2024-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'leinster_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Final (Dublin 1-19 Louth 2-12) was already present in the database from
-- an earlier phase of this project; no insert needed here.
