-- Round-by-round 2021 Leinster SHC, provincial through final. Like
-- Munster, 2021 hurling used a straight knockout format (round-robin was
-- suspended that year). Teams: Antrim, Dublin, Galway, Kilkenny, Laois,
-- Wexford -- Galway and Kilkenny had byes to the semi-finals.
with rows(round, home_county, away_county, ground_name, match_date, home_score, away_score) as (
  values
    ('Quarter-Final', 'Dublin', 'Antrim', null, date '2021-06-26', '3-31', '0-22'),
    ('Quarter-Final', 'Wexford', 'Laois', null, date '2021-06-26', '5-31', '1-23'),
    ('Semi-Final', 'Dublin', 'Galway', 'Croke Park', date '2021-07-03', '1-18', '1-14'),
    ('Semi-Final', 'Kilkenny', 'Wexford', 'Croke Park', date '2021-07-03', '2-37', '2-29')
)
insert into public.matches (
  competition_id, season, round, match_date, match_type,
  home_county_team_id, away_county_team_id, ground_id,
  competition, home_score, away_score, status, winner,
  source_provider, source_ref
)
select
  c.id, 2021, r.round, r.match_date, 'county',
  hct.id, act.id, g.id,
  c.name, r.home_score, r.away_score, 'completed',
  case
    when public.gaa_score_total(r.home_score) > public.gaa_score_total(r.away_score) then 'home'
    when public.gaa_score_total(r.home_score) < public.gaa_score_total(r.away_score) then 'away'
    else 'draw'
  end,
  'manual', 'leinster-shc-2021-' || lower(replace(r.round, ' ', '')) || '-' || lower(r.home_county) || '-' || lower(r.away_county)
from rows r
join public.competitions c on c.code = 'leinster_shc'
join public.counties hc on hc.name = r.home_county
join public.counties ac on ac.name = r.away_county
join public.county_teams hct on hct.county_id = hc.id and hct.sport_code = 'hurling'
join public.county_teams act on act.county_id = ac.id and act.sport_code = 'hurling'
left join public.grounds g on g.name = r.ground_name;

-- Kilkenny v Wexford semi-final went to extra time (level at 2-29 after
-- normal time is not the case here -- Kilkenny's 2-37 already reflects the
-- full extra-time total per the source); winner is Kilkenny.

-- Correct the Final's score (row already existed with winner set but null
-- scores): Kilkenny 1-25 Dublin 0-19.
update public.matches m
set home_score = '1-25', away_score = '0-19'
from public.competitions c
where m.competition_id = c.id and c.code = 'leinster_shc' and m.season = 2021 and m.round = 'Final';
