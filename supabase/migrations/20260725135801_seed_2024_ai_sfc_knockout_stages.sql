-- 2024 All-Ireland SFC preliminary quarter-finals, quarter-finals and
-- semi-finals. Final already in the database from an earlier phase.
-- Mayo v Derry went to extra-time level (1-12 to 0-15, 15-15) with Derry
-- winning on penalties; the schema has no penalty-shootout field, so the
-- drawn scoreline is recorded with Derry as winner.
with rows(round, home_county, away_county, ground_name, match_date, throw_in_time, home_score, away_score) as (
  values
    ('Preliminary Quarter-Final', 'Mayo', 'Derry', 'MacHale Park', date '2024-06-22', '18:30', '1-12', '0-15'),
    ('Preliminary Quarter-Final', 'Tyrone', 'Roscommon', 'Healy Park', date '2024-06-22', null, '0-12', '0-14'),
    ('Preliminary Quarter-Final', 'Galway', 'Monaghan', 'Pearse Stadium', date '2024-06-22', '16:00', '0-14', '0-11'),
    ('Preliminary Quarter-Final', 'Louth', 'Cork', 'Páirc Grattan', date '2024-06-23', '15:00', '1-9', '1-8'),

    ('Quarter-Final', 'Donegal', 'Louth', null, date '2024-06-29', null, '1-23', '0-18'),
    ('Quarter-Final', 'Kerry', 'Derry', null, date '2024-06-29', null, '0-15', '0-10'),
    ('Quarter-Final', 'Dublin', 'Galway', 'Croke Park', date '2024-06-29', null, '0-16', '0-17'),
    ('Quarter-Final', 'Armagh', 'Roscommon', null, date '2024-06-30', null, '2-12', '0-12'),

    ('Semi-Final', 'Armagh', 'Kerry', 'Croke Park', date '2024-07-13', null, '1-18', '1-16'),
    ('Semi-Final', 'Galway', 'Donegal', 'Croke Park', date '2024-07-14', null, '1-14', '0-15')
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
  'manual', 'ai-sfc-2024-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'ai_sfc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'gaelic_football'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'gaelic_football'
left join public.grounds g on g.name = r.ground_name;

-- Mayo v Derry preliminary quarter-final: correct the winner (Derry won
-- on penalties despite the recorded scoreline being level).
update public.matches m
set winner = 'away'
from public.competitions c
where m.competition_id = c.id and c.code = 'ai_sfc' and m.season = 2024
  and m.round = 'Preliminary Quarter-Final' and m.home_score = '1-12' and m.away_score = '0-15';
