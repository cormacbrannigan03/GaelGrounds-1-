-- iOS-only reward-ad feature: once a free-tier user hits the 10-match
-- cap, they can watch one rewarded video per calendar day to permanently
-- raise their own cap by 1 match. bonus_match_credits accumulates
-- (watch today, watch again tomorrow, etc.); last_ad_reward_at enforces
-- the once-daily rule. Both free-tier RLS policies from
-- 20260801023511_free_tier_match_limits.sql are redefined here to add
-- the bonus on top of the hardcoded 10 -- CHECK clauses on a policy
-- aren't ALTERable in place, so these are drop+recreate, same shape as
-- the originals otherwise.

alter table public.user_profiles
  add column if not exists bonus_match_credits int not null default 0,
  add column if not exists last_ad_reward_at date;

drop policy if exists "free tier check-in limits" on public.user_match_attendance;
drop policy if exists "free tier personal match limits" on public.user_personal_matches;

create policy "free tier check-in limits"
  on public.user_match_attendance as restrictive for insert
  to authenticated
  with check (
    (select is_premium from public.user_profiles where id = auth.uid()) = true
    or (
      public.total_match_count(auth.uid()) <
        10 + (select bonus_match_credits from public.user_profiles where id = auth.uid())
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
      public.total_match_count(auth.uid()) <
        10 + (select bonus_match_credits from public.user_profiles where id = auth.uid())
      and played_at >= '2019-01-01'
    )
  );

-- Called by the app once the reward video (or its placeholder today)
-- finishes. SECURITY DEFINER + the row lock + the date check all live
-- here specifically so the once-daily rule is enforced by the database,
-- not just by the client -- the same reasoning as every other free-tier
-- rule in this app being real server-side enforcement rather than a UI
-- suggestion.
create or replace function public.claim_ad_reward()
returns table(bonus_match_credits int, last_ad_reward_at date)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := current_date;
  v_last date;
begin
  select up.last_ad_reward_at into v_last
  from public.user_profiles up
  where up.id = auth.uid()
  for update;

  if v_last is not null and v_last = v_today then
    raise exception 'ad reward already claimed today' using errcode = 'P0001';
  end if;

  update public.user_profiles up
  set bonus_match_credits = up.bonus_match_credits + 1,
      last_ad_reward_at = v_today
  where up.id = auth.uid();

  return query
    select up.bonus_match_credits, up.last_ad_reward_at
    from public.user_profiles up
    where up.id = auth.uid();
end;
$$;

grant execute on function public.claim_ad_reward() to authenticated;
