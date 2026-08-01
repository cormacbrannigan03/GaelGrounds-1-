-- Shared secret pg_cron uses to authenticate its call to the sync-matches
-- Edge Function (which is deployed with verify_jwt=false since it's not
-- invoked by a signed-in user). Generated fresh here rather than hardcoded,
-- so this file is safe to commit — the actual value never appears in git.
--
-- After this runs, the SAME value must also be set as the Edge Function's
-- own secret so it can check incoming requests against it:
--   select decrypted_secret from vault.decrypted_secrets where name = 'sync_matches_secret';
--   supabase secrets set SYNC_SECRET=<that value>
-- (There's no API that lets a migration push a value into an Edge
-- Function's runtime environment — that one step has to happen out of
-- band. See supabase/functions/sync-matches/README.md.)
do $$
begin
  if not exists (select 1 from vault.decrypted_secrets where name = 'sync_matches_secret') then
    perform vault.create_secret(
      encode(gen_random_bytes(24), 'hex'),
      'sync_matches_secret',
      'Shared secret for pg_cron to authenticate to the sync-matches Edge Function'
    );
  end if;
end $$;
