-- 2024 All-Ireland SFC Group 3 (Donegal, Tyrone, Cork, Clare) and Group 4
-- (Kerry, Louth, Monaghan, Meath) round-robin results.
with rows(group_label, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Group 3', 'Cork', 'Clare', 'Cusack Park (Ennis)', date '2024-05-18', '1-13', '1-11'),
    ('Group 3', 'Donegal', 'Tyrone', 'MacCumhaill Park', date '2024-05-25', '0-21', '0-14'),
    ('Group 3', 'Tyrone', 'Clare', null, date '2024-06-01', '3-15', '0-10'),
    ('Group 3', 'Cork', 'Donegal', 'Páirc Uí Rinn', date '2024-06-01', '3-9', '0-16'),
    ('Group 3', 'Donegal', 'Clare', null, date '2024-06-15', '2-23', '0-5'),
    ('Group 3', 'Tyrone', 'Cork', 'O''Connor Park', date '2024-06-15', '1-18', '0-17'),

    ('Group 4', 'Kerry', 'Monaghan', null, date '2024-05-18', '0-24', '1-11'),
    ('Group 4', 'Louth', 'Meath', 'Páirc Grattan', date '2024-05-25', '3-10', '0-9'),
    ('Group 4', 'Monaghan', 'Louth', null, date '2024-06-01', '2-10', '2-10'),
    ('Group 4', 'Kerry', 'Meath', null, date '2024-06-05', '2-18', '0-9'),
    ('Group 4', 'Kerry', 'Louth', null, date '2024-06-16', '2-21', '1-10'),
    ('Group 4', 'Monaghan', 'Meath', null, date '2024-06-16', '1-17', '1-14')
)
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2024, r.group_label, r.match_date, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', 'ai-sfc-2024-' || lower(replace(r.group_label, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'ai_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;
