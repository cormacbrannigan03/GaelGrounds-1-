-- Round-by-round 2021 Munster SHC, provincial through final. 2021 used a
-- straight knockout format (the round-robin was suspended that year, part
-- of a temporary reintroduction of the pre-2018 knockout/qualifier system
-- during COVID), so this is a much smaller bracket than 2022-2025: one
-- quarter-final (Kerry doesn't play Munster hurling), two semi-finals,
-- the final.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Quarter-Final', 'Clare', 'Waterford', 'Semple Stadium', date '2021-06-27', '1-22', '0-21'),
    ('Semi-Final', 'Limerick', 'Cork', 'Semple Stadium', date '2021-07-03', '2-22', '1-17'),
    ('Semi-Final', 'Tipperary', 'Clare', 'TUS Gaelic Grounds', date '2021-07-04', '3-23', '2-22')
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
  'manual', 'munster-shc-2021-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'munster_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
left join public.grounds g on g.name = r.ground_name;

-- Final (Limerick 2-29 Tipperary 3-21) was already present in the
-- database with a score from an earlier phase of this project; no
-- insert/update needed.
