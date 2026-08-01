-- 2025 All-Ireland SFC Group 3 (Monaghan, Down, Louth, Clare) and Group 4
-- (Armagh, Dublin, Galway, Derry -- the "Group of Death") round-robin
-- results. Armagh v Derry has a confirmed winner (Armagh) but no
-- confirmed score despite repeated searches.
with rows(group_label, round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Group 3', 'Group Stage', 'Down', 'Clare', 'Cusack Park (Ennis)', date '2025-05-18', '3-27', '1-16'),
    ('Group 3', 'Group Stage', 'Monaghan', 'Louth', null, null, '1-23', '4-8'),
    ('Group 3', 'Group Stage', 'Monaghan', 'Clare', null, null, '1-25', '1-16'),
    ('Group 3', 'Group Stage', 'Down', 'Louth', 'Páirc Esler', date '2025-05-31', '0-25', '0-24'),
    ('Group 3', 'Group Stage', 'Monaghan', 'Down', 'Athletic Grounds', null, '2-27', '1-26'),
    ('Group 3', 'Group Stage', 'Louth', 'Clare', null, null, '2-17', '2-14'),

    ('Group 4', 'Group Stage', 'Dublin', 'Galway', 'Pearse Stadium', date '2025-05-17', '1-18', '2-14'),
    ('Group 4', 'Group Stage', 'Armagh', 'Dublin', 'Croke Park', date '2025-06-01', '0-24', '0-19'),
    ('Group 4', 'Group Stage', 'Derry', 'Galway', 'Celtic Park', date '2025-06-01', '2-20', '4-14'),
    ('Group 4', 'Group Stage', 'Galway', 'Armagh', 'Kingspan Breffni Park', date '2025-06-14', '2-22', '0-27'),
    ('Group 4', 'Group Stage', 'Dublin', 'Derry', null, date '2025-06-14', '0-22', '0-20')
)
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2025, r.group_label, r.match_date, 'county',
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

-- Armagh v Derry, Group 4: confirmed winner (Armagh), no confirmed score.
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2025, 'Group 4', date '2025-05-24', 'county',
  hct.id, act.id, g.id,
  c.name, null, null, 'completed', 'home',
  'manual', 'ai-sfc-2025-group4-armagh-derry'
from public.competitions c
join public.counties hc on hc.name = 'Armagh'
join public.counties ac on ac.name = 'Derry'
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = 'Athletic Grounds'
where c.code = 'ai_sfc';
