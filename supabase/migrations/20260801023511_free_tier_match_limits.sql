-- Free-tier limits: a combined 10-match cap across official check-ins
-- (user_match_attendance) and manually-added personal matches
-- (user_personal_matches), plus a 2019 cutoff on how far back either kind
-- of match can be logged. Premium accounts (user_profiles.is_premium)
-- bypass both. These are "restrictive" policies, which Postgres ANDs with
-- whatever permissive owner-insert policy already exists on each table —
-- this adds the limit without needing to know or replace the exact
-- definition of user_match_attendance's pre-existing insert policy (it
-- predates this migration history).

create or replace function public.total_match_count(p_user_id uuid)
returns int
language sql
stable
as $$
  select
    (select count(*) from public.user_match_attendance where user_id = p_user_id)
    + (select count(*) from public.user_personal_matches where user_id = p_user_id);
$$;

create policy "free tier check-in limits"
  on public.user_match_attendance as restrictive for insert
  to authenticated
  with check (
    (select is_premium from public.user_profiles where id = auth.uid()) = true
    or (
      public.total_match_count(auth.uid()) < 10
      and exists (
        select 1 from public.matches m
        where m.id = match_id and (m.played_at is null or m.played_at >= '2019-01-01')
      )
    )
  );

create policy "free tier personal match limits"
  on public.user_personal_matches as restrictive for insert
  to authenticated
  with check (
    (select is_premium from public.user_profiles where id = auth.uid()) = true
    or (
      public.total_match_count(auth.uid()) < 10
      and played_at >= '2019-01-01'
    )
  );
