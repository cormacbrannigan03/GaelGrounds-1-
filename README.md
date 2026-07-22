# GaelGrounds

Futbology, but for Gaelic games. Check in at Gaelic football, hurling, camogie
and ladies' football matches in real time, and build up a record of every
ground you've stood in — across all 32 intercounty teams.

## Features

- **Live check-ins** — check in to a match or a ground and see other fans'
  check-ins appear instantly via Supabase Realtime, no refresh needed.
- **All 32 counties, 4 codes** — every county's football, hurling, camogie
  and ladies' football teams, their grounds, and their honours.
- **Fixtures & results** — browse upcoming, live and past matches.
- **Profile & achievements** — track grounds visited, matches attended, and
  unlock badges (first ground, ground hopper, first match, all four
  provinces).

## Tech stack

- [Vite](https://vitejs.dev) + React + TypeScript
- [Supabase](https://supabase.com) — Postgres database, Auth, and Realtime
- React Router
- Plain CSS (no framework) with a light/dark-aware GAA green & gold theme

## Getting started

```bash
npm install
npm run dev
```

The app is already wired up to its Supabase project — `src/lib/supabaseClient.ts`
ships with the project URL and public anon key baked in, so it runs with no
extra setup. The anon key is safe to have in client code: every table is
protected by Row Level Security, so it can only ever do what those policies
allow (read public fixtures/grounds, or read/write a signed-in user's own
check-ins).

If you want to point the app at a different Supabase project (e.g. your own
fork of the database), copy `.env.example` to `.env` and set your own
`VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` — those override the
defaults.

## Database

The schema (in the `wksahsfkldxhusiftosj` Supabase project) covers:

- `counties`, `county_teams`, `clubs`, `grounds`, `team_grounds`, `honours` —
  reference data, publicly readable.
- `matches` — fixtures and results, publicly readable.
- `user_profiles`, `user_visits` (ground check-ins), `user_match_attendance`
  (match check-ins), `user_achievements` — check-ins are publicly readable
  (so everyone can see who's checked in to a match, like Swarm/Futbology),
  but a row can only be created, edited or deleted by the user who owns it
  (`auth.uid() = user_id`), enforced by Postgres Row Level Security.
- `achievement_definitions` — badge rules, evaluated client-side in
  `src/hooks/useAchievements.ts` after every check-in.

`user_match_attendance` and `user_visits` are added to the
`supabase_realtime` publication so the check-in panels can subscribe to
`postgres_changes` and update live.

## Scripts

- `npm run dev` — start the dev server
- `npm run build` — type-check and build for production
- `npm run preview` — preview the production build
