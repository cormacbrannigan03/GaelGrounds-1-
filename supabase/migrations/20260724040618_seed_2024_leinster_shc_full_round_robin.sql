-- 2024 Leinster SHC round-robin (Kilkenny, Antrim, Wexford, Dublin, Galway,
-- Carlow). 14 of 15 pairings confirmed via 2+ independent sources with
-- explicit 2024-dated URLs, cross-checked against gaa_score_total() to
-- rule out reversed winners. Galway v Dublin (Round 5) could not be
-- reliably confirmed: every search kept resurfacing an unrelated 2026
-- Galway v Dublin round-robin match with an almost identical dramatic
-- narrative (injury-time winning goal at Pearse Stadium), so it is left
-- out entirely rather than guessed, even for the matchup/winner.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Round 1', 'Kilkenny', 'Antrim', 'Nowlan Park', date '2024-04-21', '5-30', '0-13'),
    ('Round 1', 'Wexford', 'Dublin', 'Chadwicks Wexford Park', date '2024-04-21', '1-21', '2-18'),
    ('Round 1', 'Galway', 'Carlow', 'Pearse Stadium', date '2024-04-21', '2-25', '2-14'),
    ('Round 2', 'Antrim', 'Wexford', 'Corrigan Park', date '2024-04-27', '2-22', '2-20'),
    ('Round 2', 'Dublin', 'Carlow', 'Netwatch Cullen Park', date '2024-04-27', '1-24', '0-22'),
    ('Round 2', 'Galway', 'Kilkenny', 'Pearse Stadium', date '2024-04-28', '2-23', '0-29'),
    ('Round 3', 'Galway', 'Wexford', 'Pearse Stadium', date '2024-05-04', '1-29', '2-16'),
    ('Round 3', 'Dublin', 'Antrim', 'Parnell Park', date '2024-05-11', '3-32', '1-18'),
    ('Round 3', 'Carlow', 'Kilkenny', 'Netwatch Cullen Park', date '2024-05-11', '1-20', '1-20'),
    ('Round 4', 'Wexford', 'Carlow', 'Netwatch Cullen Park', date '2024-05-19', '2-36', '1-13'),
    ('Round 4', 'Dublin', 'Kilkenny', 'Parnell Park', date '2024-05-18', '2-23', '1-28'),
    ('Round 4', 'Antrim', 'Galway', 'Corrigan Park', date '2024-05-18', '1-14', '2-25'),
    ('Round 5', 'Kilkenny', 'Wexford', 'Nowlan Park', date '2024-05-26', '1-24', '2-20'),
    ('Round 5', 'Antrim', 'Carlow', 'Corrigan Park', date '2024-05-26', '4-22', '2-22')
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
  'manual', 'leinster-shc-2024-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'leinster_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
left join public.grounds g on g.name = r.ground_name;

-- Correct the Final's score (row already existed with winner set but null
-- scores) now confirmed via Leinster GAA's official 2024-dated result post:
-- Kilkenny 3-28 Dublin 1-18.
update public.matches m
set home_score = '3-28', away_score = '1-18'
from public.competitions c
where m.competition_id = c.id and c.code = 'leinster_shc' and m.season = 2024 and m.round = 'Final';
