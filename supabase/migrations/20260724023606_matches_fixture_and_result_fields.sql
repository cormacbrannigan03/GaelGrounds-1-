-- GAA score notation is "goals-points" (e.g. "1-14" = 1 goal + 14 points =
-- 17 total, a goal is worth 3 points) — this is the one bit of domain logic
-- needed to compare two scores, so it lives once here rather than being
-- re-implemented in the Edge Function and every client.
create function public.gaa_score_total(score text) returns int
  language sql immutable as $$
  select case
    when score is null or score !~ '^\d+-\d+$' then null
    else split_part(score, '-', 1)::int * 3 + split_part(score, '-', 2)::int
  end;
$$;

alter table public.matches
  add column competition_id uuid references public.competitions (id),
  add column season int,
  add column round text,                -- e.g. 'Final', 'Semi-Final', 'Quarter-Final', 'Round 3', 'Group A', 'Final Replay'
  add column match_date date,
  add column throw_in_time time,        -- nullable: fixtures are sometimes confirmed with a date before a throw-in time
  add column province public.province,  -- denormalized from competitions.province for provincial fixtures; null otherwise
  add column status text not null default 'scheduled'
    check (status in ('scheduled', 'postponed', 'cancelled', 'completed')),
  add column winner text check (winner in ('home', 'away', 'draw'));

comment on column public.matches.status is
  'scheduled | postponed | cancelled | completed. Not a live/in-play tracker — this app does not track live scores, only fixtures and final results.';
comment on column public.matches.winner is
  'home | away | draw, set once a result is recorded. Derived from home_score/away_score via gaa_score_total() rather than left for every consumer to re-parse GAA score notation.';

-- Backfill every existing row from played_at / home_score / away_score /
-- the free-text competition column, so nothing already in the table is
-- left with the new columns empty.
update public.matches m
set
  match_date = m.played_at::date,
  throw_in_time = m.played_at::time,
  season = extract(year from m.played_at)::int,
  status = case when m.home_score is not null and m.away_score is not null then 'completed' else 'scheduled' end,
  winner = case
    when m.home_score is null or m.away_score is null then null
    when public.gaa_score_total(m.home_score) > public.gaa_score_total(m.away_score) then 'home'
    when public.gaa_score_total(m.away_score) > public.gaa_score_total(m.home_score) then 'away'
    else 'draw'
  end;

-- Best-effort link of the old free-text competition column to the new
-- reference table + a parsed round, for the rows seeded before competitions existed.
update public.matches m
set competition_id = c.id, round = 'Final'
from public.competitions c
where c.code = 'ai_sfc' and m.competition = 'All-Ireland Senior Football Championship Final';

update public.matches m
set competition_id = c.id, round = 'Final Replay'
from public.competitions c
where c.code = 'ai_sfc' and m.competition = 'All-Ireland Senior Football Championship Final Replay';

update public.matches m
set competition_id = c.id, round = 'Semi-Final'
from public.competitions c
where c.code = 'ai_sfc' and m.competition = 'All-Ireland Senior Football Championship Semi-Final';

update public.matches m
set competition_id = c.id, round = 'Final'
from public.competitions c
where c.code = 'ai_sfc' and m.competition = 'All-Ireland Senior Football Championship'
  and m.home_score is not null; -- the pre-existing yearly rows are all finals

update public.matches m
set competition_id = c.id, round = 'Final'
from public.competitions c
where c.code = 'ai_shc' and m.competition in ('All-Ireland Senior Hurling Championship Final', 'All-Ireland Senior Hurling Championship')
  and (m.competition = 'All-Ireland Senior Hurling Championship Final' or m.home_score is not null);

update public.matches m
set competition_id = c.id, round = 'Final'
from public.competitions c
where c.code = 'ai_lgfa' and m.competition = 'All-Ireland Senior Ladies'' Football Championship';

-- The one demo row that doesn't map to a real competition in this list.
update public.matches
set round = 'Group Stage'
where competition = 'Ulster Senior Football League' and competition_id is null;
