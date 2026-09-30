-- Shared secret pg_cron uses to authenticate its call to the
-- send-activation-reminder Edge Function (deployed with verify_jwt=false
-- since it's invoked by pg_net, not a signed-in user). Same pattern as
-- sync_matches_secret / push_notify_secret.
--
-- After this runs, the SAME value must also be set as the Edge Function's
-- own secret so it can check incoming requests against it:
--   select decrypted_secret from vault.decrypted_secrets where name = 'activation_reminder_secret';
--   supabase secrets set ACTIVATION_REMINDER_SECRET=<that value>
do $$
begin
  if not exists (select 1 from vault.decrypted_secrets where name = 'activation_reminder_secret') then
    perform vault.create_secret(
      encode(gen_random_bytes(24), 'hex'),
      'activation_reminder_secret',
      'Shared secret for pg_cron to authenticate to the send-activation-reminder Edge Function'
    );
  end if;
end $$;
