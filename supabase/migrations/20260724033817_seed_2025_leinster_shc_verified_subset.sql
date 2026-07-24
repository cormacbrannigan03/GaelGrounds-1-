-- 2025 Leinster SHC round-robin research hit an unusually high hallucination
-- rate (see sync-matches/README.md "Data accuracy" for the full account):
-- several searches returned internally-contradictory scores for the same
-- fixture, and multiple results turned out to be 2026-season matches
-- mislabelled as 2025 (the current date is July 2026, so recency-biased
-- searches skew toward the season just gone). Only fixtures verified against
-- a source with an explicit 2025-dated URL or two independently-named
-- sources are inserted here. Kilkenny-Antrim, Kilkenny-Galway (round-robin),
-- Kilkenny-Wexford, Kilkenny-Offaly, Kilkenny-Dublin, Galway-Dublin,
-- Galway-Wexford, Dublin-Wexford, Dublin-Offaly, Dublin-Antrim,
-- Wexford-Antrim and Offaly-Antrim remain unverified and are deliberately
-- left out rather than guessed.

-- First, correct the Final's scores (row already existed with winner set
-- but null scores) now that the result is confirmed via rte.ie's explicitly
-- 2025-dated recap URL (rte.ie/.../2025/0608/...): Kilkenny 3-22 Galway 1-20.
update public.matches m
set home_score = '3-22', away_score = '1-20'
from public.competitions c
where m.competition_id = c.id
  and c.code = 'leinster_shc'
  and m.season = 2025
  and m.round = 'Final';

with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Round 4', 'Galway', 'Antrim', 'Pearse Stadium', date '2025-05-17', '6-27', '1-14'),
    ('Round 4', 'Wexford', 'Offaly', 'Chadwicks Wexford Park', date '2025-05-17', '2-17', '1-17')
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
  'manual', 'leinster-shc-2025-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'leinster_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
join public.grounds g on g.name = r.ground_name;
