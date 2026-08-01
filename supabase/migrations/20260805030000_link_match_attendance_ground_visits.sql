<<<<<<< HEAD
=======
-- NOTE: this file was committed to git but, like the premium migration
-- earlier tonight, never actually run against the live project until now
-- (2026-08-05, applied via the Supabase MCP tools). Found while chasing a
-- follow-up report that Profile stats didn't update live after a check-in:
-- ProfileView now subscribes to realtime changes on user_visits expecting
-- match check-ins to produce one via this trigger, so without this
-- migration applied, "Grounds visited" would never move from a match
-- check-in (only from an explicit ground check-in), independent of the
-- realtime subscription itself working correctly.
>>>>>>> county-achievements-20260804
begin;

alter table public.user_visits
  add column if not exists match_attendance_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_visits_match_attendance_id_fkey'
      and conrelid = 'public.user_visits'::regclass
  ) then
    alter table public.user_visits
      add constraint user_visits_match_attendance_id_fkey
      foreign key (match_attendance_id)
      references public.user_match_attendance(id)
      on delete cascade;
  end if;
end
$$;

create unique index if not exists user_visits_match_attendance_id_uidx
  on public.user_visits(match_attendance_id)
  where match_attendance_id is not null;

create or replace function public.log_match_attendance_ground_visit()
returns trigger
language plpgsql
security invoker
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
  on conflict (match_attendance_id)
    where match_attendance_id is not null
    do nothing;

  return new;
end;
$$;

revoke all on function public.log_match_attendance_ground_visit() from public;
grant execute on function public.log_match_attendance_ground_visit()
  to postgres, authenticated, service_role;

drop trigger if exists log_ground_visit_after_match_attendance
  on public.user_match_attendance;

create trigger log_ground_visit_after_match_attendance
after insert on public.user_match_attendance
for each row
execute function public.log_match_attendance_ground_visit();

insert into public.user_visits (
  user_id,
  ground_id,
  visited_at,
  match_attendance_id
)
select
  a.user_id,
  m.ground_id,
  coalesce(m.played_at, a.created_at, now()),
  a.id
from public.user_match_attendance as a
join public.matches as m on m.id = a.match_id
where m.ground_id is not null
on conflict (match_attendance_id)
  where match_attendance_id is not null
  do nothing;

commit;
