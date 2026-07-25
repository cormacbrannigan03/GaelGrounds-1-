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
   which resolves the county/ground/competition names to UUIDs (via
   `provider_team_aliases` / `provider_ground_aliases` /
   `provider_competition_aliases`, self-populating on first match), computes
   `status` and `winner`, and upserts into `matches`, keyed on
   `(source_provider, source_ref)` so re-syncing never duplicates a match.
   This app doesn't track live in-play scores — every match is either an
   upcoming fixture (`status = 'scheduled'`, no score) or a completed result
   (`status = 'completed'`, final score + winner); `postponed`/`cancelled`
   only ever come from a provider explicitly saying so.
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
   `external_ref,sport_code,competition,season,round,home_team,away_team,ground,match_date,throw_in_time,home_score,away_score`
   — `sport_code` is one of `gaelic_football | hurling | camogie |
   ladies_football`; `season` is the GAA year (e.g. `2026`); `round` is free
   text (`Final`, `Semi-Final`, `Round 3`...) and can be blank; `match_date`
   is `YYYY-MM-DD`; `throw_in_time` is `HH:MM` (24h) and can be blank if not
   yet confirmed; leave `home_score`/`away_score` blank for a fixture that
   hasn't been played.
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
  (external_ref, sport_code, competition, season, round, home_team_name, away_team_name, ground_name, match_date, throw_in_time)
values
  ('manual-2026-08-10-dub-kerry', 'gaelic_football', 'Tailteann Cup', 2026, 'Final', 'Dublin', 'Kerry', 'Croke Park', '2026-08-10', '15:30');
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

Deployed and live-tested against the real database during development,
twice: once for the original (matchup/score-only) schema, and again after
adding `competitions`/`season`/`round`/`match_date`/`throw_in_time`/`status`/
`winner`. Each time, a row was inserted into `manual_match_submissions`, the
function was invoked, and it correctly resolved the county names, ground
name, and competition name to their UUIDs, created the `matches` row with
every field populated, and marked the submission `applied` — then the test
data was removed. The scaffold providers (ScoreBeo/ClubZap) are, honestly,
untested beyond "returns an empty array safely when not configured," since
there's no real API to test against yet.

## Data accuracy

The `competitions` table and the researched historical results
(National Football/Hurling League, All-Ireland SFC/SHC, Tailteann Cup, Joe
McDonagh/Christy Ring/Nickey Rackard/Lory Meagher Cups, and the provincial
championships) were populated via web search against real GAA results, not
invented. Coverage is deliberately **finals-only, not exhaustive** — full
round-by-round league and group-stage data for 5 seasons across this many
competitions is well beyond what can be hand-verified reliably; that volume
of data is exactly what this ingestion pipeline exists to eventually pull
from a real fixtures API (ScoreBeo/ClubZap) or bulk CSV import instead. A
few results were left with a confirmed matchup/winner but no confirmed
exact score or date, rather than guess — `match_date`/`home_score`/
`away_score` are null on those rows.

**One important correction made during this work**: three matches seeded
early in this project as plausible-looking demo fixtures for 2026
("Armagh v Tyrone", "Cork v Limerick", "Dublin v Kerry") turned out not to
match what actually happened in the real 2026 championship once verified —
they were fabricated placeholders, not researched data. They were deleted
and replaced with the real 2026 All-Ireland series results/fixture (Limerick
beat Galway in the hurling final; the football semi-finals were Kerry v
Dublin and Mayo v Louth; the final is Kerry v Mayo). If you find other rows
that look off, `matches.source_provider = 'manual'` with a null `source_ref`
marks the original hand-seeded demo data (as opposed to anything synced by
this pipeline, which always carries a `source_ref`) — that's the data most
likely to warrant a second look.

**Round-by-round 2025 provincial-to-final coverage (AI football/hurling
only)**: after the finals-only pass above, a second pass added full
round-by-round results for the 2025 All-Ireland SFC and SHC provincial
championships (Leinster, Munster, Ulster, Connacht SFC; Leinster and Munster
SHC), per the project owner's request to narrow scope to these two
competitions for one season before deciding whether to extend further back.
Each result was verified via a targeted "Team A v Team B" search
cross-checked against 2+ independently-named sources (RTÉ, Irish Examiner,
Irish Times, GAA.ie, county GAA sites) and sanity-checked so no winner is
ever recorded with a lower `gaa_score_total()` than the loser.

Two gaps are worth calling out explicitly:

- **Connacht SFC is incomplete.** London and New York compete in this
  championship and the schema has no way to represent them as county teams,
  so any match involving either is excluded rather than guessed. This is an
  open schema question for the project owner, not yet resolved.
- **Leinster SHC 2025 is only partially covered** (two round-robin fixtures
  plus the final; the other ten round-robin pairings among Kilkenny, Galway,
  Dublin, Wexford, Offaly and Antrim are missing). This competition's
  research hit a specific, repeatable failure mode worth documenting: **the
  current date is well into the 2026 GAA season, so recency-biased searches
  for "2025" results kept surfacing 2026-season matches instead** — same
  fixture pairings, similar-looking scorelines, wrong year. Several searches
  returned a plausible score with no year signal at all; only sources whose
  URL or byline carried an explicit `2025` date were trusted in the end. This
  produced multiple false leads before being caught (e.g. a "Kilkenny 3-22
  Galway 1-20, 25 May" round-robin claim that was actually the real Final's
  scoreline attached to the wrong date; an "Offaly 2-21 Wexford 2-15"
  result that was the *2026* meeting, not 2025; a Galway–Dublin score whose
  every source URL was dated `/2026/`). Given this failure mode wasn't
  anticipated going in, **the football provincial data inserted in this same
  phase (Leinster/Munster/Ulster/Connacht SFC) has not been specifically
  re-checked for the same year-bleed risk** and would benefit from a spot
  re-verification pass using explicit `"2025"`-qualified queries before being
  treated as fully trustworthy.

**Round-by-round 2024 provincial-to-final coverage**: the same six
competitions (Leinster/Munster/Ulster/Connacht SFC, Leinster/Munster SHC)
were then done for 2024, at the user's request to extend one season back
before deciding on 2021–2023. This pass benefited from two things the 2025
pass didn't have: the season is now old enough that recency-biased search
contamination mostly pulls in *other* old seasons rather than "live" ones,
and Munster GAA's official site (munster.gaa.ie) turned out to publish a
dedicated, dated event page per fixture with the final score in the title —
using that as the primary source made Munster SFC and Munster SHC 2024
(all 14 matches) the highest-confidence data gathered in this project so
far. Leinster SHC 2024 came out **14 of 15 round-robin pairings** confirmed
(a big improvement on 2025's 2 of 15) — the lone gap, Galway v Dublin Round
5, is excluded rather than guessed because every search for it kept
resurfacing an unrelated *2026* Galway–Dublin match with an almost
identical dramatic finish (injury-time winning goal at Pearse Stadium),
making the real 2024 result impossible to isolate.

This phase also **incidentally cross-checked several of the 2025 football
scores flagged as unverified above**: searching for 2024 results repeatedly
surfaced the correct 2025 scores as a side effect (e.g. the 2025 Ulster SFC
final, Donegal 2-23 Armagh 0-28, and the 2025 Connacht SFC final, Galway
1-17 Mayo 1-15, both reappeared with explicit `/2025/`-dated sources while
chasing their 2024 equivalents) — those specific figures can now be treated
as confirmed rather than merely "not yet re-checked." The rest of the 2025
football provincial data is still unverified for year-bleed risk.

Connacht SFC 2024 has the same London/New York gap as 2025 (2 of the 3
quarter-finals excluded). Leinster SFC 2024's Louth v Wexford quarter-final
has a confirmed matchup/winner but no confirmed score, same treatment as
the older finals noted above.

**Round-by-round 2023 provincial-to-final coverage**: same six
competitions, one season further back. Munster GAA's official event pages
again made Munster SFC and Munster SHC 2023 fully confirmed (all 14
matches). Leinster SHC 2023 came out **14 of 15 round-robin pairings**
confirmed — Galway v Westmeath (Round 3) has a confirmed winner (Galway,
via elimination against the final standings table: Galway finished
3 wins/2 draws/0 losses and their other four 2023 results are each
individually confirmed) but no confirmed score. One reversed-winner catch
in Leinster SFC 2023: a search claimed "Westmeath winning 1-11 to Louth's
2-10" in the quarter-final, which is arithmetically backwards (16 > 14);
corrected to Louth as the winner, matching Louth's independently-confirmed
comeback-from-8-down and their run to the final.

Connacht SFC 2023 is the most London/New York-affected season yet: of the
6 pre-final matches, 3 involved London or New York (Sligo v London
quarter-final, New York v Leitrim quarter-final, Sligo v New York
semi-final) and are excluded, leaving only 2 insertable matches plus the
final.

Ulster SFC 2023's final went to penalties after a draw (Armagh 0-18 Derry
1-15 AET); the drawn scoreline is recorded as the match result with Derry
as the winner, since the schema has no separate field for a penalty
shoot-out result.

**Round-by-round 2022 provincial-to-final coverage, now with throw-in
times**: at the project owner's request, this pass also captures
`throw_in_time` (not just `match_date`) and double-checks ground names.
Throw-in times are meaningfully harder to source than scores/dates/venues:
they only ever appear in pre-match preview articles (never in post-match
recaps, which is where the bulk of this project's data comes from), and
those previews are far less durably indexed. Coverage ended up patchy and
concentrated on the biggest games — semi-finals and finals mostly have a
dedicated "throw-in time" preview article (irishnews.com and
irishexaminer.com both run a recurring "Team v Team: throw-in time, TV
details" series); quarter-finals and round-robin fixtures usually don't.
Munster GAA's own event pages occasionally embed a time range (e.g. "4:00
pm - 6:00 pm") directly in the fixture listing, which was the single best
source found. No time was ever guessed — it's null wherever no source
confirmed one.

This season also surfaced the worst source contamination yet, on two
fronts:

- **Ulster SFC 2022** — every quarter-final/semi-final search returned
  contradictory or wrong-year results, including one case where a search
  itself flagged the problem: "Donegal did play Down in Ulster
  Championship semi-finals, but these matches occurred in different years
  (2023, 2025, and 2026), not in 2022." Rather than guess a bracket that
  couldn't be pinned down, only the preliminary round (Donegal 2-20 Cavan
  1-15) and the final are recorded; the quarter-finals and semi-finals are
  left out entirely for this season.
- **Leinster SHC 2022** — Round 1 (3 matches) and one Round 2 match
  (Kilkenny v Laois) are confirmed; the remaining nine round-robin
  fixtures hit the same kind of contradictions and are left out.
- **Connacht SFC 2022** was the first season back after COVID with both
  London and New York competing, and every pre-final match this project
  could verify (e.g. Mayo v London) involved one of them — so under the
  existing London/New York schema-gap policy, nothing before the final was
  insertable this season at all.

Munster SFC and Munster SHC 2022, and Leinster SFC 2022, came through
cleanly by contrast (same high-confidence official-event-page sourcing as
2023/2024), with only one score gap (Leinster SFC's Westmeath v Laois
quarter-final: winner confirmed, score not).
