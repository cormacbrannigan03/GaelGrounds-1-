-- Shared secret the friend-request and live-checkin triggers use to
-- authenticate their call to the send-push-notification Edge Function
-- (deployed with verify_jwt=false, same reasoning as sync-matches: it's
-- invoked by a Postgres trigger via pg_net, not a signed-in user).
-- A separate secret from sync_matches_secret on purpose, so the two
-- functions don't share a blast radius.
--
-- After this runs, the SAME value must also be set as the Edge Function's
-- own secret:
--   select decrypted_secret from vault.decrypted_secrets where name = 'push_notify_secret';
--   supabase secrets set PUSH_NOTIFY_SECRET=<that value>
-- (No API lets a migration push a value into an Edge Function's runtime
-- environment -- that step happens out of band, same as SYNC_SECRET.)
do $$
begin
  if not exists (select 1 from vault.decrypted_secrets where name = 'push_notify_secret') then
    perform vault.create_secret(
      encode(gen_random_bytes(24), 'hex'),
      'push_notify_secret',
      'Shared secret for Postgres triggers to authenticate to the send-push-notification Edge Function'
    );
  end if;
end $$;
