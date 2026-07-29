-- Full 10-match round-robin for 2024 Munster SHC, all confirmed via
-- official munster.gaa.ie event pages (dedicated page per fixture with
-- final score, date and venue).
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Round 1', 'Limerick', 'Clare', 'Cusack Park (Ennis)', date '2024-04-21', '3-15', '1-18'),
    ('Round 1', 'Waterford', 'Cork', 'Walsh Park', date '2024-04-21', '2-25', '1-25'),
    ('Round 2', 'Cork', 'Clare', 'Páirc Uí Chaoimh', date '2024-04-28', '3-24', '3-26'),
    ('Round 2', 'Limerick', 'Tipperary', 'TUS Gaelic Grounds', date '2024-04-28', '2-27', '0-18'),
    ('Round 3', 'Waterford', 'Tipperary', 'Walsh Park', date '2024-05-04', '3-21', '1-27'),
    ('Round 3', 'Cork', 'Limerick', 'Páirc Uí Chaoimh', date '2024-05-11', '3-28', '3-26'),
    ('Round 4', 'Clare', 'Waterford', 'Cusack Park (Ennis)', date '2024-05-19', '4-21', '2-26'),
    ('Round 4', 'Cork', 'Tipperary', 'Semple Stadium', date '2024-05-19', '4-30', '1-21'),
    ('Round 5', 'Clare', 'Tipperary', 'Semple Stadium', date '2024-05-26', '1-24', '0-24'),
    ('Round 5', 'Limerick', 'Waterford', 'TUS Gaelic Grounds', date '2024-05-26', '0-30', '2-14')
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
  'manual', 'munster-shc-2024-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'munster_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
left join public.grounds g on g.name = r.ground_name;

-- Final (Limerick 1-26 Clare 1-20) was already present in the database with
-- a score from an earlier phase of this project; no insert/update needed.
