-- Fires the send-waitlist-email Edge Function the moment someone joins
-- the waiting list, so the confirmation email is triggered by the
-- database itself rather than the website remembering to call something
-- after a successful insert -- same dispatch pattern as the friend-request
-- and live-checkin push notifications.
create or replace function public.notify_waitlist_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://wksahsfkldxhusiftosj.supabase.co/functions/v1/send-waitlist-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-waitlist-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'waitlist_email_secret')
    ),
    body := jsonb_build_object(
      'email', new.email
    )
  );

  return new;
end;
$$;

create trigger on_waitlist_signup_created
  after insert on public.waitlist_signups
  for each row
  execute function public.notify_waitlist_signup();
