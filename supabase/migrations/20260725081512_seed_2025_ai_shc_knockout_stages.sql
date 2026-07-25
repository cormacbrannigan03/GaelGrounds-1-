-- 2025 All-Ireland SHC. Unlike football, hurling's All-Ireland series has
-- no separate group stage -- it feeds directly from the provincial
-- round-robin standings: Leinster/Munster champions go straight to the
-- semi-finals, runners-up to the quarter-finals, and 3rd-place teams
-- (Dublin from Leinster, Tipperary from Munster in 2025) join two Joe
-- McDonagh Cup teams (Kildare, Laois) in the preliminary quarter-finals.
-- Final already in the database.
with rows(round, home_county, away_county, ground_name, match_date, throw_in_time, home_score, away_score) as (
  values
    ('Preliminary Quarter-Final', 'Tipperary', 'Laois', null, date '2025-06-14', null, '3-32', '0-18'),
    ('Preliminary Quarter-Final', 'Dublin', 'Kildare', 'St Conleth''s Park', date '2025-06-14', null, '3-25', '0-13'),

    ('Quarter-Final', 'Tipperary', 'Galway', 'TUS Gaelic Grounds', date '2025-06-21', null, '1-28', '2-17'),
    ('Quarter-Final', 'Dublin', 'Limerick', 'Croke Park', date '2025-06-21', null, '2-24', '0-28'),

    ('Semi-Final', 'Cork', 'Dublin', 'Croke Park', date '2025-07-05', null, '7-26', '2-21'),
    ('Semi-Final', 'Tipperary', 'Kilkenny', 'Croke Park', date '2025-07-06', '16:00', '4-20', '0-30')
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
  'manual', 'ai-shc-2025-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'ai_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
left join public.grounds g on g.name = r.ground_name;
