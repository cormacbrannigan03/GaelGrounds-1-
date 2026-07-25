-- Round-by-round 2022 Munster SFC, provincial through final, with
-- throw-in times where a dedicated preview/official source confirmed one
-- (per project owner's request starting this season). Confirmed via
-- official munster.gaa.ie event pages plus dedicated "throw-in time"
-- preview articles (irishnews.com, radiokerry.ie, limerickgaa.ie).
with rows(round, home_county, away_county, ground_name, match_date, throw_in_time, home_score, away_score) as (
  values
    ('Quarter-Final', 'Tipperary', 'Waterford', 'Fraher Field', date '2022-04-30', null, '2-13', '1-8'),
    ('Quarter-Final', 'Limerick', 'Clare', 'Cusack Park (Ennis)', date '2022-04-30', '16:00', '2-16', '1-19'),
    ('Semi-Final', 'Kerry', 'Cork', 'Páirc Uí Rinn', date '2022-05-07', '18:00', '0-23', '0-11'),
    ('Semi-Final', 'Limerick', 'Tipperary', 'Semple Stadium', date '2022-05-14', '19:00', '2-10', '0-10')
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
  'manual', 'munster-sfc-2022-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'munster_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Quarter-Final note: Limerick won 4-1 on penalties after the above score
-- (2-16 to 1-19) was level following extra time; schema has no separate
-- penalty-shootout field, so the drawn/extra-time scoreline is recorded
-- with Limerick as winner (matches Munster GAA's own event-page framing).
update public.matches m
set winner = 'home'
from public.competitions c
where m.competition_id = c.id and c.code = 'munster_sfc' and m.season = 2022
  and m.round = 'Quarter-Final' and m.home_score = '2-16';

-- Final's throw-in time (row already existed with scores from an earlier
-- phase of this project): confirmed 3pm via limerickgaa.ie's own headline.
update public.matches m
set throw_in_time = '15:00'
from public.competitions c
where m.competition_id = c.id and c.code = 'munster_sfc' and m.season = 2022 and m.round = 'Final';
