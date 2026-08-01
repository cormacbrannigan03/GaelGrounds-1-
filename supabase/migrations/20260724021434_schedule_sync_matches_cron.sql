select cron.schedule(
  'sync-matches-every-30-min',
  '*/30 * * * *',
  $$
  select net.http_post(
    url := 'https://wksahsfkldxhusiftosj.supabase.co/functions/v1/sync-matches?cron=1',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-sync-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'sync_matches_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
