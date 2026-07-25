-- 2024 All-Ireland SHC. Same format as 2025 -- no group stage; feeds directly
-- from the Leinster/Munster provincial round-robin standings. Munster
-- champion (Limerick) and Leinster champion (Kilkenny) go straight to the
-- semi-finals; Munster runner-up (Clare) and Leinster runner-up (Dublin) go
-- to the quarter-finals; Munster 3rd (Cork) and Leinster 3rd (Wexford) join
-- two Joe McDonagh Cup teams (Offaly, Laois) in the preliminary
-- quarter-finals. Final already in the database.
with rows(round, home_county, away_county, ground_name, match_date, throw_in_time, home_score, away_score) as (
  values
    ('Preliminary Quarter-Final', 'Cork', 'Offaly', 'O''Connor Park', date '2024-06-15', null, '4-25', '3-19'),
    ('Preliminary Quarter-Final', 'Laois', 'Wexford', 'O''Moore Park', date '2024-06-15', '17:00', '0-20', '0-32'),

    ('Quarter-Final', 'Clare', 'Wexford', 'Semple Stadium', date '2024-06-22', '15:15', '2-28', '1-19'),
    ('Quarter-Final', 'Cork', 'Dublin', 'Semple Stadium', date '2024-06-22', null, '0-26', '0-21'),

    ('Semi-Final', 'Clare', 'Kilkenny', 'Croke Park', date '2024-07-06', '15:00', '0-24', '2-16'),
    ('Semi-Final', 'Limerick', 'Cork', 'Croke Park', date '2024-07-07', '16:00', '0-29', '1-28')
)
insert into public.matches (
  competition_id, season, round, match_date, throw_in_time, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2024, r.round, r.match_date, r.throw_in_time::time, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', 'ai-shc-2024-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'ai_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
left join public.grounds g on g.name = r.ground_name;
