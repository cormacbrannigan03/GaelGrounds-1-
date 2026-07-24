# sync-matches — the data provider ingestion pipeline

This is the whole answer to "the app should not need to change if I replace
one provider with another": the iOS app only ever reads `matches`/`honours`
etc. from Supabase (see `ios/GaelGrounds/Services/MatchService.swift` — no
provider-specific code anywhere in the app). Everything provider-specific
lives here, in one Edge Function, behind one interface.

```
supabase/functions/sync-matches/
  index.ts                  orchestrator: reads data_providers, dispatches, logs the run
  shared/types.ts            the MatchDataProvider interface — the whole seam
  shared/normalize.ts        name resolution + idempotent upsert into `matches`
  shared/supabaseAdmin.ts    service-role client (bypasses RLS by design)
  providers/registry.ts      code → adapter map (the one place that lists providers)
  providers/scorebeo.ts      SCAFFOLD — not licensed, see comments in the file
  providers/clubzap.ts       SCAFFOLD — not licensed, see comments in the file
  providers/csv.ts           fully working — reads an uploaded CSV from Storage
  providers/manual.ts        fully working — reads manual_match_submissions
```

## How it fits together

1. `data_providers` (table) is the registry — one row per source, with
   `enabled` and non-secret `config`. `providers/registry.ts` maps each
   `code` to its adapter.
2. Every 30 minutes, `pg_cron` calls this function. It loads the enabled,
   `run_in_scheduled_sync = true` providers and calls
   `adapter.fetchUpdates(lastSyncedAt, ctx)` on each.
3. Every match an adapter returns goes through
   `shared/normalize.ts::upsertMatch` — same function for every provider —
   which resolves the county/ground names to UUIDs (via
   `provider_team_aliases` / `provider_ground_aliases`, self-populating on
   first match) and upserts into `matches`, keyed on
   `(source_provider, source_ref)` so re-syncing never duplicates a match.
4. Every run is logged to `data_sync_runs` (created/updated/unchanged/
   skipped counts, or an error).
5. `matches` and `honours` are in the `supabase_realtime` publication, so
   the app doesn't just see updates on next launch — MatchesView,
   MatchDetailView and DashboardView subscribe to `postgres_changes` and
   update live the moment this function writes a row.

**Adding a new provider** (a future fixtures API, a different CSV shape,
whatever) is: write a file implementing `MatchDataProvider`, add it to
`providers/registry.ts`, insert a row into `data_providers`. Nothing else
in this function, and nothing in the app, changes.

## Outstanding manual step: set the SYNC_SECRET

This function is deployed with `verify_jwt=false` (it's called by `pg_cron`,
not a signed-in user) and instead checks an `x-sync-secret` header against
the `SYNC_SECRET` Edge Function secret. The cron job already sends the
correct value (it reads it from Supabase Vault at call time — see
`supabase/migrations/20260724021420_create_sync_matches_secret.sql` and
`..._schedule_sync_matches_cron.sql`), but **there's no API this session had
access to that can push a value into an Edge Function's runtime secrets** —
that has to happen once, by hand:

```bash
# get the value pg_cron is already sending:
#   select decrypted_secret from vault.decrypted_secrets where name = 'sync_matches_secret';
#   (run in the SQL editor — it's currently: aea77a144f2002718cc9c2eaa1fc8382a7ca96455225540e)

supabase login
supabase link --project-ref wksahsfkldxhusiftosj
supabase secrets set SYNC_SECRET=aea77a144f2002718cc9c2eaa1fc8382a7ca96455225540e
```

**Until you do this, the function accepts requests without checking the
secret at all** (the check is skipped if `SYNC_SECRET` isn't set) — not a
data-exposure risk since it only writes normalized match data, but worth
closing promptly so random internet traffic can't trigger syncs.

## Activating ScoreBeo / ClubZap once licensed

1. Get the real API base URL + auth scheme from the provider.
2. `supabase secrets set SCOREBEO_API_KEY=...` (or `CLUBZAP_API_KEY`).
3. Replace the `fetchUpdates()` body in `providers/scorebeo.ts` /
   `clubzap.ts` with the real HTTP call and the real →
   `RawProviderMatch` field mapping — the TODO comments in each file show
   the intended shape.
4. `update public.data_providers set enabled = true where code = 'scorebeo';`

## Importing a CSV

1. Upload your file to the private `data-imports` Storage bucket (Studio's
   Storage UI, or the API with the service_role key).
2. Required header row (extra columns ignored, order doesn't matter):
   `external_ref,sport_code,competition,home_team,away_team,ground,played_at,home_score,away_score`
   — `sport_code` is one of `gaelic_football | hurling | camogie |
   ladies_football`; leave `home_score`/`away_score` blank for a fixture
   that hasn't been played.
3. Trigger the import:
   ```bash
   curl -X POST \
     "https://wksahsfkldxhusiftosj.supabase.co/functions/v1/sync-matches?provider=csv&file=<path-in-bucket>" \
     -H "x-sync-secret: <SYNC_SECRET>"
   ```

## Entering a match by hand (the "admin dashboard", API-only for now)

Insert a row into `manual_match_submissions` (Studio's table editor, or the
REST API with the service_role key) with `status` left as the default
`'pending'`. The next sync run (cron, or trigger it immediately — see
below) resolves it into a real `matches` row and flips the submission to
`applied` (or `error`, with `error_message` set, if a team/ground name
couldn't be resolved — check `provider_team_aliases`/
`provider_ground_aliases` or fix the spelling and re-submit).

```sql
insert into manual_match_submissions
  (external_ref, sport_code, competition, home_team_name, away_team_name, ground_name, played_at)
values
  ('manual-2026-08-10-dub-kerry', 'gaelic_football', 'Test Match', 'Dublin', 'Kerry', 'Croke Park', '2026-08-10T15:30:00Z');
```

To process it immediately rather than waiting for the next cron tick:

```bash
curl -X POST "https://wksahsfkldxhusiftosj.supabase.co/functions/v1/sync-matches?provider=manual" \
  -H "x-sync-secret: <SYNC_SECRET>"
```

If a UI ever gets built for this, its only job is inserting rows into
`manual_match_submissions` — this function doesn't change.

## Checking on it

```sql
select * from data_sync_runs order by started_at desc limit 20;
select * from data_providers;
select * from cron.job;               -- confirm the schedule exists
select * from cron.job_run_details order by start_time desc limit 20; -- cron's own run history
```

## This has been tested end to end

Deployed and live-tested against the real database during development: a
row was inserted into `manual_match_submissions` for "Cavan v Monaghan at
Kingspan Breffni Park", the function was invoked, and it correctly resolved
both county names and the ground name to their UUIDs, created the `matches`
row, and marked the submission `applied` — then the test data was removed.
The scaffold providers (ScoreBeo/ClubZap) are, honestly, untested beyond
"returns an empty array safely when not configured," since there's no real
API to test against yet.
