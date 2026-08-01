# GaelGrounds

Futbology, but for Gaelic games. Check in at Gaelic football, hurling, camogie
and ladies' football matches in real time, and build up a record of every
ground you've stood in — across all 32 intercounty teams.

**Active development has moved to the native iOS app** — see
[`ios/README.md`](ios/README.md) for the SwiftUI project and setup
instructions. The React web client below is kept for reference but is no
longer being developed; both talk to the same Supabase project.

## Features

- **Live check-ins** — check in to a match or a ground and see other fans'
  check-ins appear instantly via Supabase Realtime, no refresh needed.
- **All 32 counties, 4 codes** — every county's football, hurling, camogie
  and ladies' football teams, their grounds, and their roll of honour.
- **Fixtures & results** — browse upcoming, live and past matches, with
  search, and check in to a match any time after the fact.
- **Profile & achievements** — track grounds visited, matches attended, and
  unlock badges (first ground, ground hopper, first match, all four
  provinces).

## Project layout

- `ios/` — native SwiftUI app (current development target). Start here.
- `src/` — the original React/Vite web client (feature-complete, no longer
  actively developed).
- `supabase/` — database migrations and the `sync-matches` Edge Function
  (the data provider ingestion pipeline — see below).

## Where match data comes from

Both clients only ever *read* `matches`/`honours` from Supabase — neither
app talks to ScoreBeo, ClubZap, or any other data source directly. All of
that lives server-side in one Edge Function,
[`supabase/functions/sync-matches`](supabase/functions/sync-matches/README.md),
behind a single `MatchDataProvider` interface. A registry table
(`data_providers`) decides which sources are active; swapping one provider
for another, or adding a new one, never touches the apps. Currently wired
up:

- **CSV import** — fully working, reads an uploaded file from Storage.
- **Manual entry** — fully working, backed by `manual_match_submissions`
  (no admin UI yet by design; see the function's README for how to drive it
  today).
- **ScoreBeo / ClubZap** — scaffolded adapters ready for real API docs and
  credentials once licensed; currently no-ops.

It runs on a `pg_cron` schedule every 30 minutes, and `matches`/`honours`
are in the `supabase_realtime` publication, so a synced update shows up in
the apps live, not just on next launch. Full details, including the one
manual setup step still outstanding, are in that function's README.

## Database

Both clients share one Supabase project (`wksahsfkldxhusiftosj`):

- `counties`, `county_teams`, `clubs`, `grounds`, `team_grounds`, `honours` —
  reference data, publicly readable.
- `matches` — fixtures and results, publicly readable, written by
  `sync-matches` (see above) or hand-seeded demo data.
- `user_profiles`, `user_visits` (ground check-ins), `user_match_attendance`
  (match check-ins), `user_achievements` — check-ins are publicly readable
  (so everyone can see who's checked in to a match, like Swarm/Futbology),
  but a row can only be created, edited or deleted by the user who owns it
  (`auth.uid() = user_id`), enforced by Postgres Row Level Security.
- `achievement_definitions` — badge rules, evaluated client-side after every
  check-in (`src/hooks/useAchievements.ts` in the web client,
  `ios/GaelGrounds/Services/AchievementsService.swift` in the iOS app).
- `data_providers`, `data_sync_runs`, `provider_team_aliases`,
  `provider_ground_aliases`, `manual_match_submissions` — the ingestion
  pipeline's internal tables. RLS-enabled with zero policies: only the
  Edge Function's service_role key can touch them, the apps' anon key
  can't see them at all.

`user_match_attendance`, `user_visits`, `matches` and `honours` are all in
the `supabase_realtime` publication, so both check-ins and provider-synced
match updates propagate live.

## Web client (reference)

```bash
npm install
npm run dev
```

`src/lib/supabaseClient.ts` ships with the project URL and public anon key
baked in — the anon key is safe client-side, since every table is behind
Row Level Security. To point it at a different Supabase project, copy
`.env.example` to `.env` and set your own `VITE_SUPABASE_URL` /
`VITE_SUPABASE_ANON_KEY`.

- `npm run dev` — start the dev server
- `npm run build` — type-check and build for production
- `npm run preview` — preview the production build
