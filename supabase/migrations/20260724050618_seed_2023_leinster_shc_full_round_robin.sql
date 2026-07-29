-- 2023 Leinster SHC round-robin (Kilkenny, Galway, Dublin, Wexford,
-- Antrim, Westmeath). 14 of 15 pairings confirmed with scores; Galway v
-- Westmeath (Round 3) has a confirmed winner (Galway, corroborated by the
-- final standings table: Galway finished 3 wins/2 draws/0 losses, and
-- their other 4 results are individually confirmed, leaving this as their
-- 3rd win by elimination) but no confirmed score despite repeated
-- searches, so it's inserted with a null score rather than guessed.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Round 1', 'Dublin', 'Antrim', 'Corrigan Park', date '2023-04-22', '1-19', '1-19'),
    ('Round 1', 'Galway', 'Wexford', 'Pearse Stadium', date '2023-04-22', '0-24', '2-12'),
    ('Round 1', 'Kilkenny', 'Westmeath', 'Nowlan Park', date '2023-04-22', '0-29', '0-7'),
    ('Round 2', 'Dublin', 'Westmeath', 'Parnell Park', date '2023-04-29', '2-23', '1-14'),
    ('Round 2', 'Galway', 'Kilkenny', null, date '2023-04-29', '1-25', '0-28'),
    ('Round 2', 'Wexford', 'Antrim', 'Chadwicks Wexford Park', date '2023-04-29', '1-30', '1-26'),
    ('Round 3', 'Dublin', 'Wexford', 'Croke Park', date '2023-05-06', '1-22', '0-23'),
    ('Round 3', 'Kilkenny', 'Antrim', 'Corrigan Park', date '2023-05-07', '5-31', '3-20'),
    ('Round 4', 'Dublin', 'Kilkenny', 'Nowlan Park', date '2023-05-20', '0-21', '0-27'),
    ('Round 4', 'Westmeath', 'Wexford', 'Chadwicks Wexford Park', date '2023-05-21', '4-18', '2-22'),
    ('Round 4', 'Galway', 'Antrim', 'Pearse Stadium', date '2023-05-21', '5-27', '2-12'),
    ('Round 5', 'Dublin', 'Galway', 'Croke Park', date '2023-05-28', '2-22', '1-25'),
    ('Round 5', 'Wexford', 'Kilkenny', 'Chadwicks Wexford Park', date '2023-05-28', '4-23', '5-18'),
    ('Round 5', 'Antrim', 'Westmeath', 'Cusack Park (Ennis)', date '2023-05-28', '4-24', '1-19')
)
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2023, r.round, r.match_date, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', 'leinster-shc-2023-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'leinster_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
left join public.grounds g on g.name = r.ground_name;

-- Galway v Westmeath, Round 3: confirmed winner (Galway), no confirmed
-- score.
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2023, 'Round 3', date '2023-05-06', 'county',
  hct.id, act.id, null,
  c.name, null, null, 'completed', 'home',
  'manual', 'leinster-shc-2023-round3-galway-westmeath'
from public.competitions c
join public.counties hc on hc.name = 'Galway'
join public.counties ac on ac.name = 'Westmeath'
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
where c.code = 'leinster_shc';

-- Final's score (Kilkenny 4-21 Galway 2-26) was already present in the
-- database from an earlier phase of this project; no update needed.
