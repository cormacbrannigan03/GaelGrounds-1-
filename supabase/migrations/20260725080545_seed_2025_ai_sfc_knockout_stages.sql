-- 2025 All-Ireland SFC preliminary quarter-finals, quarter-finals and
-- semi-finals. Final already in the database from an earlier phase.
with rows(round, home_county, away_county, ground_name, match_date, throw_in_time, home_score, away_score) as (
  values
    ('Preliminary Quarter-Final', 'Kerry', 'Cavan', 'Fitzgerald Stadium', date '2025-06-21', '15:30', '3-20', '1-17'),
    ('Preliminary Quarter-Final', 'Dublin', 'Cork', 'Croke Park', date '2025-06-21', '18:15', '1-19', '1-16'),
    ('Preliminary Quarter-Final', 'Down', 'Galway', 'Páirc Esler', date '2025-06-22', '13:45', '3-21', '2-26'),
    ('Preliminary Quarter-Final', 'Donegal', 'Louth', 'MacCumhaill Park', date '2025-06-22', '16:00', '2-22', '0-12'),

    ('Quarter-Final', 'Tyrone', 'Dublin', 'Croke Park', date '2025-06-28', null, '0-23', '0-16'),
    ('Quarter-Final', 'Donegal', 'Monaghan', 'Croke Park', date '2025-06-28', null, '1-26', '1-20'),
    ('Quarter-Final', 'Kerry', 'Armagh', 'Croke Park', date '2025-06-29', null, '0-32', '1-21'),
    ('Quarter-Final', 'Meath', 'Galway', null, date '2025-06-29', null, '2-16', '2-15'),

    ('Semi-Final', 'Kerry', 'Tyrone', 'Croke Park', date '2025-07-12', null, '1-20', '0-17'),
    ('Semi-Final', 'Donegal', 'Meath', 'Croke Park', date '2025-07-13', null, '3-26', '0-15')
)
insert into public.matches (
  competition_id, season, round, match_date, throw_in_time, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2025, r.round, r.match_date, r.throw_in_time::time, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', 'ai-sfc-2025-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'ai_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;
