-- Fires the send-push-notification Edge Function when a check-in happens
-- while its match is actually live -- reproducing ios/GaelGrounds/Models/
-- Match.swift's `isLive` exactly (not yet scored, and now() falls within
-- 2.5 hours after played_at), so "live" means the same thing here as it
-- does in the app. Retroactive/back-dated check-ins into past matches,
-- and check-ins before throw-in, silently do nothing -- there's no
-- trigger on user_personal_matches at all, since manually-added matches
-- are never a live event by definition.
create or replace function public.notify_live_checkin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_played_at timestamptz;
  v_home_score text;
  v_away_score text;
begin
  select played_at, home_score, away_score
    into v_played_at, v_home_score, v_away_score
  from public.matches
  where id = new.match_id;

  if v_played_at is not null
     and v_home_score is null
     and v_away_score is null
     and now() >= v_played_at
     and now() <= v_played_at + interval '2.5 hours'
  then
    perform net.http_post(
      url := 'https://wksahsfkldxhusiftosj.supabase.co/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-push-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_notify_secret')
      ),
      body := jsonb_build_object(
        'type', 'live_checkin',
        'user_id', new.user_id,
        'match_id', new.match_id
      )
    );
  end if;

  return new;
end;
$$;

create trigger on_live_checkin_created
  after insert on public.user_match_attendance
  for each row
  execute function public.notify_live_checkin();
