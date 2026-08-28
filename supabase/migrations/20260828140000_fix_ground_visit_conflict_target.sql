-- log_match_attendance_ground_visit's ON CONFLICT clause only named the
-- (match_attendance_id) partial unique index, but user_visits has a SECOND,
-- independent unique constraint on (user_id, ground_id, visited_at).
--
-- Real production case that surfaced this: two different real matches
-- (Galway v Dublin and Louth v Monaghan) share the exact same ground
-- (Croke Park) and, per the imported fixture data, the exact same recorded
-- kickoff timestamp. A user who'd already checked into the first match had
-- a user_visits row at that (ground, timestamp) pair; checking into the
-- second, unrelated match then tried to insert a second row at that same
-- pair, which the (match_attendance_id) conflict target has no idea about
-- and so doesn't catch -- the insert fails with a raw
-- "duplicate key value violates unique constraint" error, uncaught, which
-- aborts the whole transaction and blocks the check-in itself, not just
-- the ground-visit bookkeeping. The website surfaced this as a generic
-- "past the free plan's limit" message, which was actively misleading:
-- the account was Premium and nowhere near any limit.
--
-- An unqualified `on conflict do nothing` (no target specified) is
-- documented Postgres behaviour for "applies to violation of any unique or
-- exclusion constraint" -- correctly handles both existing constraints
-- without needing to enumerate them, and doesn't change behaviour for the
-- normal case (a genuine duplicate check-in on the same match_attendance_id
-- still gets silently skipped, exactly as before). The real check-in
-- (user_match_attendance) must always succeed regardless of whether the
-- secondary ground-visit bookkeeping hits a timestamp coincidence like
-- this -- that's the derived/secondary record, not the source of truth.
create or replace function public.log_match_attendance_ground_visit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  insert into public.user_visits (
    user_id,
    ground_id,
    visited_at,
    match_attendance_id
  )
  select
    new.user_id,
    m.ground_id,
    coalesce(m.played_at, new.created_at, now()),
    new.id
  from public.matches as m
  where m.id = new.match_id
    and m.ground_id is not null
  on conflict do nothing;

  return new;
end;
$$;
