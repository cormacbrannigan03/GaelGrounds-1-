-- Round-by-round 2021 Munster SFC, provincial through final. 2021 was the
-- first season back after the COVID-delayed 2020 championship, played in a
-- compressed June-July window largely behind closed doors -- which also
-- meant very little pre-match "throw-in time" media coverage survived to
-- be searchable, so times are mostly null this season.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Quarter-Final', 'Limerick', 'Waterford', null, date '2021-06-26', '4-18', '0-12'),
    ('Quarter-Final', 'Kerry', 'Clare', null, date '2021-06-26', '3-22', '1-11'),
    ('Semi-Final', 'Cork', 'Limerick', 'TUS Gaelic Grounds', date '2021-07-10', '1-16', '0-11'),
    ('Semi-Final', 'Kerry', 'Tipperary', null, date '2021-07-10', '1-19', '1-8')
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
  'manual', 'munster-sfc-2021-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'munster_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Final (Kerry 4-22 Cork 1-9) was already present in the database with a
-- score from an earlier phase of this project; no insert/update needed.
