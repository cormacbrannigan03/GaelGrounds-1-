# sync-public-fixtures

Scrapes public fixture/result sources (RTÉ, plus any additional iCal/JSON-LD
sources configured in `data_providers.config` for the `public_sources` row)
and upserts them into `matches`, using the same `(source_provider,
source_ref)` idempotency key as `sync-matches`.

**Note on how this file came to exist here:** this function was deployed
directly to the live Supabase project without ever being committed to this
repo — a security audit turned it up as a live, `service_role`-privileged
function with no corresponding source file anywhere in version control. This
directory captures its exact deployed source as of that audit, so it's
reviewable and diffable going forward like every other function.

## Auth

Same shared-secret pattern as `sync-matches` (`x-sync-secret` header), with
one addition: if the `SYNC_SECRET` Edge Function secret isn't set, it falls
back to comparing a SHA-256 hash of the supplied secret against
`data_providers.config.syncSecretSha256` — and correctly denies the request
if neither is configured, rather than failing open. (`sync-matches` and the
notification functions originally had a fail-open bug here — missing secret
env var meant the check was skipped entirely — fixed in the same audit that
found this file's drift; this function's logic was already fail-closed.)

## Invocation

```
POST /functions/v1/sync-public-fixtures?season=2026
POST /functions/v1/sync-public-fixtures?season=2026&dry_run=1
```
