-- The client-side signUp() flow tried to insert into user_profiles
-- immediately after auth.signUp(), but that only works if email
-- confirmation is off and a session comes back instantly. With email
-- confirmation on (the case here), signUp() returns no session, so that
-- insert runs as the anon role -- which has no grants on user_profiles at
-- all -- and fails with "permission denied for table user_profiles" for
-- every single signup, confirmed or not.
--
-- Standard Supabase fix: a trigger on auth.users creates the profile row
-- server-side the instant the account exists, regardless of confirmation
-- state or which client/session is doing the asking. security definer
-- means it runs with the function owner's privileges, sidestepping the
-- anon-grant problem entirely.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_profiles (id, display_name, supported_county_id)
  values (
    new.id,
    new.raw_user_meta_data ->> 'display_name',
    nullif(new.raw_user_meta_data ->> 'supported_county_id', '')::uuid
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();
