-- 2022 Ulster SFC: only the preliminary round could be reliably confirmed
-- this season. Every quarter-final/semi-final search hit contradictory or
-- wrong-year results (a recurring problem for Ulster football specifically
-- across every season researched this project) -- including one explicit
-- correction from a search itself: "Donegal did play Down in Ulster
-- Championship semi-finals, but these matches occurred in different years
-- (2023, 2025, and 2026), not in 2022." Rather than guess the bracket,
-- quarter-finals and semi-finals are left out entirely for this
-- competition/season -- see sync-matches/README.md for the full account.
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2022, 'Preliminary Round', date '2022-04-16', 'county',
  hct.id, act.id, g.id,
  c.name, '2-20', '1-15', 'completed', 'home',
  'manual', 'ulster-sfc-2022-preliminaryround-donegal-cavan'
from public.competitions c
join public.counties hc on hc.name = 'Donegal'
join public.counties ac on ac.name = 'Cavan'
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = 'MacCumhaill Park'
where c.code = 'ulster_sfc';

-- Correct the Final's score (row already existed with winner set but null
-- scores): Derry 1-16 Donegal 1-14 after extra time.
update public.matches m
set home_score = '1-16', away_score = '1-14'
from public.competitions c
where m.competition_id = c.id and c.code = 'ulster_sfc' and m.season = 2022 and m.round = 'Final';
