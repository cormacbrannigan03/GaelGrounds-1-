-- Keep social data available to signed-in users while preventing anonymous
-- API clients from enumerating profiles, match attendance and ground visits.
drop policy if exists "profiles are publicly readable" on public.user_profiles;
drop policy if exists "users can view their own profile" on public.user_profiles;
create policy "signed-in users can view profiles"
  on public.user_profiles for select to authenticated using (true);

drop policy if exists "match attendance is publicly readable" on public.user_match_attendance;
drop policy if exists "users can view their own attendance" on public.user_match_attendance;
create policy "signed-in users can view match attendance"
  on public.user_match_attendance for select to authenticated using (true);

drop policy if exists "ground visits are publicly readable" on public.user_visits;
drop policy if exists "users can view their own visits" on public.user_visits;
create policy "signed-in users can view ground visits"
  on public.user_visits for select to authenticated using (true);

-- USING protects the old row; WITH CHECK also protects the updated row so a
-- user cannot reassign ownership during an otherwise permitted update.
drop policy if exists "users can update their own attendance" on public.user_match_attendance;
create policy "users can update their own attendance"
  on public.user_match_attendance for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "users can update their own visits" on public.user_visits;
create policy "users can update their own visits"
  on public.user_visits for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Grants are a separate access-control layer from RLS. Anonymous clients do
-- not need any access to account-owned tables; authenticated users receive
-- only the operations used by GaelGrounds.
revoke all on table public.user_profiles from anon;
revoke all on table public.user_match_attendance from anon;
revoke all on table public.user_visits from anon;
revoke all on table public.friendships from anon;
revoke all on table public.user_achievements from anon;
revoke all on table public.user_personal_matches from anon;

revoke all on table public.user_profiles from authenticated;
grant select, insert, update on table public.user_profiles to authenticated;
revoke all on table public.user_match_attendance from authenticated;
grant select, insert, update, delete on table public.user_match_attendance to authenticated;
revoke all on table public.user_visits from authenticated;
grant select, insert, update, delete on table public.user_visits to authenticated;
revoke all on table public.friendships from authenticated;
grant select, insert, update, delete on table public.friendships to authenticated;
revoke all on table public.user_achievements from authenticated;
grant select, insert on table public.user_achievements to authenticated;
revoke all on table public.user_personal_matches from authenticated;
grant select, insert, update, delete on table public.user_personal_matches to authenticated;

-- The public waitlist endpoint remains insert-only. Normalize future email
-- addresses before the existing unique constraint is checked.
revoke all on table public.waitlist_signups from anon, authenticated;
grant insert on table public.waitlist_signups to anon, authenticated;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to postgres, supabase_admin, service_role;

create or replace function private.normalize_waitlist_email()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.email := lower(btrim(new.email));
  return new;
end;
$$;

revoke all on function private.normalize_waitlist_email() from public, anon, authenticated;

drop trigger if exists normalize_waitlist_email_before_insert on public.waitlist_signups;
create trigger normalize_waitlist_email_before_insert
  before insert on public.waitlist_signups
  for each row execute function private.normalize_waitlist_email();

-- Privileged trigger functions do not belong in the Data API's public schema.
create or replace function private.notify_waitlist_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform net.http_post(
    url := 'https://wksahsfkldxhusiftosj.supabase.co/functions/v1/send-waitlist-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-waitlist-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'waitlist_email_secret'
      )
    ),
    body := jsonb_build_object('email', new.email)
  );
  return new;
end;
$$;

revoke all on function private.notify_waitlist_signup() from public, anon, authenticated, service_role;

drop trigger if exists on_waitlist_signup_created on public.waitlist_signups;
create trigger on_waitlist_signup_created
  after insert on public.waitlist_signups
  for each row execute function private.notify_waitlist_signup();

drop function if exists public.notify_waitlist_signup();
