-- Round-by-round 2025 Leinster SFC, provincial through final. Each result
-- verified via targeted "Team A v Team B" searches cross-checked against
-- 2+ independently-named sources (RTE, Irish Examiner, Irish Times, GAA.ie,
-- county GAA sites) and sanity-checked with gaa_score_total() so no winner
-- is recorded with a lower score than the loser. Mirrored to disk from the
-- live database for version-control parity; originally applied directly via
-- apply_migration.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Preliminary Round', 'Laois', 'Wexford', null, date '2025-04-05', '2-20', '2-11'),
    ('Preliminary Round', 'Wicklow', 'Longford', null, date '2025-04-06', '2-23', '1-20'),
    ('Preliminary Round', 'Meath', 'Carlow', null, date '2025-04-06', '1-30', '0-19'),
    ('Quarter-Final', 'Kildare', 'Westmeath', null, date '2025-04-12', '2-17', '0-21'),
    ('Quarter-Final', 'Meath', 'Offaly', null, date '2025-04-13', '1-25', '0-21'),
    ('Quarter-Final', 'Dublin', 'Wicklow', 'Aughrim County Ground', date '2025-04-13', '2-21', '0-18'),
    ('Quarter-Final', 'Louth', 'Laois', null, date '2025-04-13', '2-16', '0-17'),
    ('Semi-Final', 'Louth', 'Kildare', null, date '2025-04-27', '1-18', '0-18'),
    ('Semi-Final', 'Meath', 'Dublin', 'O''Moore Park', date '2025-04-27', '0-23', '1-16')
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
  'manual', 'leinster-sfc-2025-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'leinster_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Final (Louth 3-14 Meath 1-18) was already present in the database from an
-- earlier phase of this project; no insert needed here.
