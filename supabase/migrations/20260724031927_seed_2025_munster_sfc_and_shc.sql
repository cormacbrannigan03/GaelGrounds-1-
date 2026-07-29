-- Round-by-round 2025 Munster SFC and Munster SHC, provincial through final.
-- Same verification bar as the Leinster SFC seed: 2+ independently-named
-- sources per result, arithmetic sanity-checked via gaa_score_total().
-- Mirrored to disk from the live database for version-control parity;
-- originally applied directly via apply_migration.
with rows(sport_code, competition_code, round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('gaelic_football', 'munster_sfc', 'Quarter-Final', 'Cork', 'Limerick', null, date '2025-04-05', '0-24', '0-13'),
    ('gaelic_football', 'munster_sfc', 'Quarter-Final', 'Tipperary', 'Waterford', null, date '2025-04-05', '1-22', '1-19'),
    ('gaelic_football', 'munster_sfc', 'Semi-Final', 'Clare', 'Tipperary', 'Cusack Park (Ennis)', date '2025-04-19', '2-18', '1-15'),
    ('gaelic_football', 'munster_sfc', 'Semi-Final', 'Kerry', 'Cork', 'Páirc Uí Chaoimh', date '2025-04-19', '3-21', '1-25'),

    ('hurling', 'munster_shc', 'Round 1', 'Clare', 'Cork', 'Cusack Park (Ennis)', date '2025-04-20', '3-21', '2-24'),
    ('hurling', 'munster_shc', 'Round 1', 'Tipperary', 'Limerick', 'Semple Stadium', date '2025-04-20', '2-23', '2-23'),
    ('hurling', 'munster_shc', 'Round 2', 'Waterford', 'Clare', 'Walsh Park', date '2025-04-27', '2-23', '0-21'),
    ('hurling', 'munster_shc', 'Round 2', 'Cork', 'Tipperary', 'Páirc Uí Chaoimh', date '2025-04-27', '4-27', '0-24'),
    ('hurling', 'munster_shc', 'Round 3', 'Limerick', 'Waterford', 'Walsh Park', date '2025-05-03', '0-28', '0-22'),
    ('hurling', 'munster_shc', 'Round 3', 'Tipperary', 'Clare', 'Cusack Park (Ennis)', date '2025-05-10', '4-18', '2-21'),
    ('hurling', 'munster_shc', 'Round 4', 'Tipperary', 'Waterford', 'Semple Stadium', date '2025-05-18', '1-30', '1-21'),
    ('hurling', 'munster_shc', 'Round 4', 'Limerick', 'Cork', null, date '2025-05-18', '3-26', '1-16'),
    ('hurling', 'munster_shc', 'Round 5', 'Cork', 'Waterford', 'Páirc Uí Chaoimh', date '2025-05-25', '2-25', '1-22'),
    ('hurling', 'munster_shc', 'Round 5', 'Clare', 'Limerick', 'TUS Gaelic Grounds', date '2025-05-25', '3-20', '0-24')
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
  'manual', r.competition_code || '-2025-' || lower(replace(r.round, ' ', '-')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = r.competition_code
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = r.sport_code::public.sport_code
join public.county_teams act on act.county_id = ac.id and act.sport_code = r.sport_code::public.sport_code
left join public.grounds g on g.name = r.ground_name;

-- Finals (Munster SFC: Kerry 4-20 Clare 0-21; Munster SHC: Cork 2-27 Limerick
-- 1-30) were already present in the database from an earlier phase of this
-- project; no insert needed here.
