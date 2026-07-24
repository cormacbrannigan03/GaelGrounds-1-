-- Full 10-match round-robin for 2023 Munster SHC, all confirmed via
-- official munster.gaa.ie event pages.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Round 1', 'Limerick', 'Waterford', 'Semple Stadium', date '2023-04-23', '1-18', '0-19'),
    ('Round 1', 'Tipperary', 'Clare', 'Cusack Park (Ennis)', date '2023-04-23', '5-22', '3-23'),
    ('Round 2', 'Clare', 'Limerick', 'TUS Gaelic Grounds', date '2023-04-29', '1-24', '2-20'),
    ('Round 2', 'Cork', 'Waterford', 'Páirc Uí Chaoimh', date '2023-04-30', '0-27', '0-18'),
    ('Round 3', 'Cork', 'Tipperary', 'Páirc Uí Chaoimh', date '2023-05-06', '4-19', '2-25'),
    ('Round 3', 'Clare', 'Waterford', 'Semple Stadium', date '2023-05-13', '2-22', '0-16'),
    ('Round 4', 'Tipperary', 'Limerick', 'Semple Stadium', date '2023-05-21', '0-25', '0-25'),
    ('Round 4', 'Clare', 'Cork', 'Cusack Park (Ennis)', date '2023-05-21', '2-22', '3-18'),
    ('Round 5', 'Waterford', 'Tipperary', 'Semple Stadium', date '2023-05-28', '1-24', '0-21'),
    ('Round 5', 'Limerick', 'Cork', 'TUS Gaelic Grounds', date '2023-05-28', '3-25', '1-30')
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
  'manual', 'munster-shc-2023-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'munster_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
left join public.grounds g on g.name = r.ground_name;

-- Final (Limerick 1-23 Clare 1-22) was already present in the database
-- with a score from an earlier phase of this project; no insert/update
-- needed.
