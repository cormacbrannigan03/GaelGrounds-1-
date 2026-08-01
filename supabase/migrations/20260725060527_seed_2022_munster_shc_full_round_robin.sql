-- Full 10-match round-robin for 2022 Munster SHC, all confirmed via
-- official munster.gaa.ie event pages. Throw-in times included where a
-- source confirmed one.
with rows(round, home_county, away_county, ground_name, match_date, throw_in_time, home_score, away_score) as (
  values
    ('Round 1', 'Limerick', 'Cork', 'Páirc Uí Chaoimh', date '2022-04-17', '16:00', '2-25', '1-17'),
    ('Round 1', 'Waterford', 'Tipperary', 'Walsh Park', date '2022-04-17', null, '2-24', '2-20'),
    ('Round 2', 'Limerick', 'Waterford', 'TUS Gaelic Grounds', date '2022-04-23', null, '0-30', '2-21'),
    ('Round 2', 'Clare', 'Tipperary', 'Cusack Park (Ennis)', date '2022-04-24', null, '3-21', '2-16'),
    ('Round 3', 'Clare', 'Cork', 'Semple Stadium', date '2022-05-01', null, '0-28', '2-20'),
    ('Round 3', 'Limerick', 'Tipperary', 'TUS Gaelic Grounds', date '2022-05-08', null, '3-21', '0-23'),
    ('Round 4', 'Clare', 'Limerick', 'Cusack Park (Ennis)', date '2022-05-15', null, '0-24', '1-21'),
    ('Round 4', 'Cork', 'Waterford', 'Walsh Park', date '2022-05-15', null, '2-22', '1-19'),
    ('Round 5', 'Cork', 'Tipperary', 'Semple Stadium', date '2022-05-22', null, '3-30', '1-24'),
    ('Round 5', 'Clare', 'Waterford', 'Cusack Park (Ennis)', date '2022-05-22', null, '3-31', '2-22')
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
  'manual', 'munster-shc-2022-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'munster_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
left join public.grounds g on g.name = r.ground_name;

-- Final's throw-in time (row already existed with scores from an earlier
-- phase of this project): confirmed 4pm via rte.ie's recap.
update public.matches m
set throw_in_time = '16:00'
from public.competitions c
where m.competition_id = c.id and c.code = 'munster_shc' and m.season = 2022 and m.round = 'Final';
