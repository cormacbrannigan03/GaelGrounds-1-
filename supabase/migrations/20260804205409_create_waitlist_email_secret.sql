-- Shared secret the waitlist-signup trigger uses to authenticate its call
-- to the send-waitlist-email Edge Function (deployed with verify_jwt=false,
-- same reasoning as sync-matches and send-push-notification: it's invoked
-- by a Postgres trigger via pg_net, not a signed-in user). A separate
-- secret from push_notify_secret/sync_matches_secret on purpose, so the
-- three functions don't share a blast radius.
--
-- After this runs, the SAME value must also be set as the Edge Function's
-- own secret:
--   select decrypted_secret from vault.decrypted_secrets where name = 'waitlist_email_secret';
--   supabase secrets set WAITLIST_EMAIL_SECRET=<that value>
-- (No API lets a migration push a value into an Edge Function's runtime
-- environment -- that step happens out of band, same as SYNC_SECRET and
-- PUSH_NOTIFY_SECRET.)
do $$
begin
  if not exists (select 1 from vault.decrypted_secrets where name = 'waitlist_email_secret') then
    perform vault.create_secret(
      encode(gen_random_bytes(24), 'hex'),
      'waitlist_email_secret',
      'Shared secret for the waitlist-signup trigger to authenticate to the send-waitlist-email Edge Function'
    );
  end if;
end $$;
