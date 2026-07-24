import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { MatchDataProvider, ProviderContext, RawProviderMatch, SportCode } from "../shared/types.ts";
import { createAdminClient } from "../shared/supabaseAdmin.ts";

const BUCKET = "data-imports";
const VALID_SPORT_CODES: readonly SportCode[] = ["gaelic_football", "hurling", "camogie", "ladies_football"];

/**
 * CSV import provider. Unlike ScoreBeo/ClubZap this needs no external API —
 * it reads a file you've uploaded to the private `data-imports` Storage
 * bucket and parses it directly, so it's fully working today.
 *
 * Expected header row (order doesn't matter, extra columns are ignored):
 *   external_ref,sport_code,competition,home_team,away_team,ground,played_at,home_score,away_score
 *
 * - external_ref: any string unique to this fixture, used for dedup on
 *   re-import (e.g. "csv-2026-championship-r1-dublin-meath").
 * - sport_code: one of gaelic_football | hurling | camogie | ladies_football
 * - played_at: ISO 8601 (e.g. 2026-08-10T15:30:00Z)
 * - home_score/away_score: GAA notation ("1-14"), leave blank for a fixture
 *   that hasn't been played yet.
 *
 * Unlike the API providers, this one isn't run on the cron sweep
 * (data_providers.run_in_scheduled_sync = false for 'csv') — it only runs
 * when explicitly requested with a file, since there's no "poll for new
 * files" cursor concept: you upload a file, then trigger a sync for it.
 *
 *   POST /functions/v1/sync-matches?provider=csv&file=<path-in-bucket>
 */
export const csvProvider: MatchDataProvider = {
  code: "csv",

  async fetchUpdates(_sinceIso: string | null, ctx: ProviderContext): Promise<RawProviderMatch[]> {
    const path = ctx.params.get("file");
    if (!path) {
      throw new Error(
        `csv provider requires a ?file=<path> query param pointing at an object in the "${BUCKET}" storage bucket`,
      );
    }

    const supabase = createAdminClient();
    const { data, error } = await supabase.storage.from(BUCKET).download(path);
    if (error || !data) {
      throw new Error(`could not download "${path}" from bucket "${BUCKET}": ${error?.message ?? "not found"}`);
    }

    const text = await data.text();
    return parseCsv(text);
  },
};

function parseCsv(text: string): RawProviderMatch[] {
  const rows = splitCsvRows(text).filter((row) => row.some((cell) => cell.trim() !== ""));
  if (rows.length === 0) return [];

  const header = rows[0].map((h) => h.trim().toLowerCase());
  const col = (name: string) => header.indexOf(name);

  const idx = {
    externalRef: col("external_ref"),
    sportCode: col("sport_code"),
    competition: col("competition"),
    homeTeam: col("home_team"),
    awayTeam: col("away_team"),
    ground: col("ground"),
    playedAt: col("played_at"),
    homeScore: col("home_score"),
    awayScore: col("away_score"),
  };

  const required: (keyof typeof idx)[] = ["externalRef", "sportCode", "competition", "homeTeam", "awayTeam", "playedAt"];
  const missing = required.filter((key) => idx[key] === -1);
  if (missing.length > 0) {
    throw new Error(`CSV is missing required column(s): ${missing.join(", ")}`);
  }

  const matches: RawProviderMatch[] = [];
  for (let i = 1; i < rows.length; i++) {
    const cells = rows[i];
    const get = (index: number) => (index >= 0 ? (cells[index] ?? "").trim() : "");

    const sportCode = get(idx.sportCode);
    if (!VALID_SPORT_CODES.includes(sportCode as SportCode)) {
      console.log(`[csv] row ${i + 1}: skipping, invalid sport_code "${sportCode}"`);
      continue;
    }

    const homeScore = get(idx.homeScore);
    const awayScore = get(idx.awayScore);

    matches.push({
      externalRef: get(idx.externalRef),
      sportCode: sportCode as SportCode,
      competition: get(idx.competition),
      homeTeamName: get(idx.homeTeam),
      awayTeamName: get(idx.awayTeam),
      groundName: idx.ground >= 0 ? get(idx.ground) || null : null,
      playedAt: get(idx.playedAt),
      homeScore: homeScore || null,
      awayScore: awayScore || null,
    });
  }

  return matches;
}

/** Minimal RFC4180-ish CSV row splitter — handles quoted fields containing commas/newlines/escaped quotes. */
function splitCsvRows(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const c = text[i];

    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += c;
      }
      continue;
    }

    if (c === '"') {
      inQuotes = true;
    } else if (c === ",") {
      row.push(field);
      field = "";
    } else if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i++;
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
    } else {
      field += c;
    }
  }

  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }

  return rows;
}
