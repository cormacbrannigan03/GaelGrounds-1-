-- Finds anyone who signed up 48+ hours ago, still has zero logged matches,
-- isn't premium (a premium pitch doesn't fit someone who already pays),
-- and hasn't been reminded yet -- then fires the same "get Premium free
-- for inviting 3 mates" activation email that already worked manually,
-- personalized per recipient via send-activation-reminder.
create or replace function public.send_activation_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  secret text;
begin
  select decrypted_secret into secret
  from vault.decrypted_secrets
  where name = 'activation_reminder_secret';

  if secret is null then
    raise warning 'activation_reminder_secret not found in vault; skipping run';
    return;
  end if;

  for rec in
    select up.id, au.email, up.display_name, up.referral_code
    from public.user_profiles up
    join auth.users au on au.id = up.id
    where up.created_at <= now() - interval '48 hours'
      and up.is_premium = false
      and up.activation_reminder_sent_at is null
      and not exists (
        select 1 from public.user_match_attendance m where m.user_id = up.id
      )
  loop
    perform net.http_post(
      url := 'https://wksahsfkldxhusiftosj.supabase.co/functions/v1/send-activation-reminder',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-activation-reminder-secret', secret
      ),
      body := jsonb_build_object(
        'email', rec.email,
        'displayName', rec.display_name,
        'referralCode', rec.referral_code
      )
    );

    -- Marked sent immediately (not after confirming the HTTP call
    -- succeeded) so a transient email-provider failure can't cause the
    -- next hourly run to retry it forever -- same tradeoff the existing
    -- sync-matches/push-notification cron jobs make elsewhere in this
    -- project. A one-off missed reminder is cheap; a duplicate-spam loop
    -- isn't.
    update public.user_profiles
    set activation_reminder_sent_at = now()
    where id = rec.id;
  end loop;
end;
$$;

select cron.schedule(
  'send-activation-reminders-hourly',
  '0 * * * *',
  $$ select public.send_activation_reminders(); $$
);
