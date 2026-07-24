import type { MatchDataProvider, ProviderContext, RawProviderMatch } from "../shared/types.ts";

/**
 * ScoreBeo adapter — SCAFFOLD, not a working integration.
 *
 * I don't have ScoreBeo API docs or credentials, so I can't write real
 * request/response mapping here without inventing field names that would
 * silently be wrong. This file is deliberately structured as the adapter
 * *will* look once it's real, so activating it later is:
 *
 *   1. Get the API base URL + auth scheme from ScoreBeo once licensed.
 *   2. Set them as Edge Function secrets: SCOREBEO_BASE_URL, SCOREBEO_API_KEY
 *      (`supabase secrets set SCOREBEO_API_KEY=...`).
 *   3. Replace the body of fetchUpdates() below with the real HTTP call and
 *      the real → RawProviderMatch field mapping.
 *   4. Flip data_providers.enabled to true for the 'scorebeo' row.
 *
 * Nothing else changes — normalize.ts, index.ts, the other providers, and
 * the app are all untouched by this.
 */
export const scorebeoProvider: MatchDataProvider = {
  code: "scorebeo",

  async fetchUpdates(_sinceIso: string | null, _ctx: ProviderContext): Promise<RawProviderMatch[]> {
    const apiKey = Deno.env.get("SCOREBEO_API_KEY");
    if (!apiKey) {
      console.log("[scorebeo] SCOREBEO_API_KEY not set — skipping (not yet licensed/configured)");
      return [];
    }

    // TODO once licensed: replace with the real ScoreBeo endpoint + mapping.
    // const baseUrl = Deno.env.get("SCOREBEO_BASE_URL") ?? "https://api.scorebeo.example";
    // const res = await fetch(`${baseUrl}/fixtures?since=${sinceIso ?? ""}`, {
    //   headers: { Authorization: `Bearer ${apiKey}` },
    // });
    // if (!res.ok) throw new Error(`ScoreBeo request failed: ${res.status} ${await res.text()}`);
    // const payload = await res.json();
    // return payload.fixtures.map(mapScoreBeoFixture);

    console.log("[scorebeo] adapter not yet implemented — see comments in providers/scorebeo.ts");
    return [];
  },
};
