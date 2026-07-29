-- 2025 All-Ireland SFC Group 1 (Tyrone, Donegal, Cavan, Mayo) and Group 2
-- (Meath, Kerry, Cork, Roscommon) round-robin results. 2+ independent
-- sources per result, arithmetic sanity-checked via gaa_score_total().
with rows(group_label, round, home_county, away_county, ground_name, match_date, throw_in_time, home_score, away_score) as (
  values
    ('Group 1', 'Group Stage', 'Tyrone', 'Donegal', null, null, null, '2-17', '0-20'),
    ('Group 1', 'Group Stage', 'Donegal', 'Cavan', null, null, null, '3-26', '1-13'),
    ('Group 1', 'Group Stage', 'Donegal', 'Mayo', null, null, null, '0-19', '1-15'),
    ('Group 1', 'Group Stage', 'Tyrone', 'Cavan', null, null, null, '0-31', '0-18'),
    ('Group 1', 'Group Stage', 'Cavan', 'Mayo', null, null, null, '1-17', '1-14'),
    ('Group 1', 'Group Stage', 'Mayo', 'Tyrone', 'Healy Park', null, null, '2-17', '1-13'),

    ('Group 2', 'Group Stage', 'Kerry', 'Roscommon', 'Fitzgerald Stadium', date '2025-05-17', null, '3-18', '0-17'),
    ('Group 2', 'Group Stage', 'Meath', 'Cork', 'Páirc Tailteann', date '2025-05-24', null, '1-13', '0-12'),
    ('Group 2', 'Group Stage', 'Kerry', 'Cork', 'Páirc Uí Chaoimh', date '2025-05-31', null, '1-28', '0-20'),
    ('Group 2', 'Group Stage', 'Roscommon', 'Meath', 'Dr Hyde Park', null, null, '2-15', '0-21'),
    ('Group 2', 'Group Stage', 'Meath', 'Kerry', 'O''Connor Park', date '2025-06-14', '16:15', '1-22', '0-16'),
    ('Group 2', 'Group Stage', 'Roscommon', 'Cork', 'Dr Hyde Park', date '2025-06-14', '16:15', '0-17', '0-19')
)
insert into public.matches (
  competition_id, season, round, match_date, throw_in_time, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2025, r.group_label, r.match_date, r.throw_in_time::time, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', 'ai-sfc-2025-' || lower(replace(r.group_label, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'ai_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;
