-- Fires the send-push-notification Edge Function whenever a new friend
-- request is created, so the addressee gets a push. This is a database
-- trigger rather than a client-side call after the insert, so it can't be
-- skipped by a buggy or bypassed client -- same reasoning as enforcing the
-- free-tier match limits via RLS instead of trusting the app.
create or replace function public.notify_friend_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://wksahsfkldxhusiftosj.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_notify_secret')
    ),
    body := jsonb_build_object(
      'type', 'friend_request',
      'requester_id', new.requester_id,
      'addressee_id', new.addressee_id
    )
  );
  return new;
end;
$$;

create trigger on_friend_request_created
  after insert on public.friendships
  for each row
  when (new.status = 'pending')
  execute function public.notify_friend_request();
