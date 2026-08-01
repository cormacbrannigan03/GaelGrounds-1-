-- 2024 All-Ireland SFC Group 1 (Armagh, Galway, Derry, Westmeath) and
-- Group 2 (Dublin, Mayo, Roscommon, Cavan) round-robin results.
with rows(group_label, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Group 1', 'Galway', 'Derry', 'Pearse Stadium', date '2024-05-18', '2-14', '0-15'),
    ('Group 1', 'Armagh', 'Westmeath', null, date '2024-05-25', '0-16', '0-11'),
    ('Group 1', 'Armagh', 'Derry', 'Celtic Park', date '2024-06-02', '3-17', '0-15'),
    ('Group 1', 'Westmeath', 'Galway', 'Cusack Park (Mullingar)', date '2024-06-02', '0-11', '1-12'),
    ('Group 1', 'Derry', 'Westmeath', null, date '2024-06-15', '2-7', '0-9'),
    ('Group 1', 'Armagh', 'Galway', 'Páirc Seán Mac Diarmada', date '2024-06-16', '0-16', '1-12'),

    ('Group 2', 'Dublin', 'Roscommon', 'Croke Park', date '2024-05-25', '2-19', '0-13'),
    ('Group 2', 'Mayo', 'Cavan', 'MacHale Park', date '2024-05-18', '0-20', '1-8'),
    ('Group 2', 'Cavan', 'Dublin', null, date '2024-06-01', '0-13', '5-17'),
    ('Group 2', 'Mayo', 'Roscommon', 'Dr Hyde Park', date '2024-06-01', '2-14', '1-15'),
    ('Group 2', 'Roscommon', 'Cavan', 'Pearse Park', date '2024-06-15', '3-20', '1-20'),
    ('Group 2', 'Dublin', 'Mayo', null, date '2024-06-16', '0-17', '0-17')
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
