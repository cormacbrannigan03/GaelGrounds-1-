-- 2022 Leinster SHC (Kilkenny, Galway, Dublin, Wexford, Westmeath, Laois).
-- Round 1 (3 matches) and one Round 2 match (Kilkenny v Laois) confirmed;
-- the remaining round-robin fixtures hit repeated contradictory/wrong-year
-- results during research (a recurring problem this season for Ulster
-- football and now Leinster hurling) and are left out rather than
-- guessed -- see sync-matches/README.md.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Round 1', 'Wexford', 'Galway', 'Chadwicks Wexford Park', date '2022-04-16', '1-19', '1-19'),
    ('Round 1', 'Kilkenny', 'Westmeath', 'Nowlan Park', date '2022-04-16', '5-23', '1-19'),
    ('Round 1', 'Dublin', 'Laois', 'Parnell Park', date '2022-04-16', '1-20', '2-15'),
    ('Round 2', 'Kilkenny', 'Laois', 'Nowlan Park', date '2022-04-23', '3-34', '1-18')
)
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2022, r.round, r.match_date, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', 'leinster-shc-2022-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'leinster_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
left join public.grounds g on g.name = r.ground_name;

-- Correct the Final's score and throw-in time (row already existed with
-- winner set but null scores): Kilkenny 0-22 Galway 0-17, 7pm.
update public.matches m
set home_score = '0-22', away_score = '0-17', throw_in_time = '19:00'
from public.competitions c
where m.competition_id = c.id and c.code = 'leinster_shc' and m.season = 2022 and m.round = 'Final';
