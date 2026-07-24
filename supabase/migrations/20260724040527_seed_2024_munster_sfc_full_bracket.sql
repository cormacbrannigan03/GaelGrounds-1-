-- Round-by-round 2024 Munster SFC, provincial through final. All four
-- results confirmed via official munster.gaa.ie event pages.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Quarter-Final', 'Cork', 'Limerick', 'Páirc Uí Chaoimh', date '2024-04-07', '3-13', '0-11'),
    ('Quarter-Final', 'Waterford', 'Tipperary', 'Fraher Field', date '2024-04-07', '2-7', '1-5'),
    ('Semi-Final', 'Kerry', 'Cork', 'Fitzgerald Stadium', date '2024-04-20', '0-18', '1-12'),
    ('Semi-Final', 'Clare', 'Waterford', 'Fraher Field', date '2024-04-20', '2-20', '1-9')
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
  'manual', 'munster-sfc-2024-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'munster_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Final (Kerry 0-23 Clare 1-13) was already present in the database from an
-- earlier phase of this project; no insert needed here.
