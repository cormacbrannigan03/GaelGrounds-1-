-- Round-by-round 2023 Munster SFC, provincial through final. Kerry and
-- Limerick (2022 finalists) had byes to the semi-finals. All results
-- confirmed via official munster.gaa.ie event pages.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Quarter-Final', 'Tipperary', 'Waterford', 'Semple Stadium', date '2023-04-09', '3-9', '1-11'),
    ('Quarter-Final', 'Clare', 'Cork', 'Cusack Park (Ennis)', date '2023-04-09', '0-14', '0-13'),
    ('Semi-Final', 'Kerry', 'Tipperary', 'Fitzgerald Stadium', date '2023-04-22', '0-25', '0-5'),
    ('Semi-Final', 'Clare', 'Limerick', 'TUS Gaelic Grounds', date '2023-04-22', '1-16', '0-16')
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
  'manual', 'munster-sfc-2023-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'munster_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Final (Kerry 5-14 Clare 0-15) was already present in the database with a
-- score from an earlier phase of this project; no insert/update needed.
