import type { MatchDataProvider, ProviderContext, RawProviderMatch, UpsertResult } from "../shared/types.ts";
import { createAdminClient } from "../shared/supabaseAdmin.ts";

/**
 * Manual-entry provider — the backing API for the "admin dashboard"
 * requirement. There's no UI yet (by design, for now); rows land in
 * `manual_match_submissions` however is most convenient today — Supabase
 * Studio's table editor, or a POST to the Supabase REST API with the
 * service_role key — and this provider is what turns a pending row into a
 * real, resolved `matches` row. When a UI does get built, its only job is
 * writing rows into that same table; this provider doesn't change.
 */
export const manualProvider: MatchDataProvider = {
  code: "manual",

  async fetchUpdates(_sinceIso: string | null, _ctx: ProviderContext): Promise<RawProviderMatch[]> {
    const supabase = createAdminClient();
    const { data, error } = await supabase
      .from("manual_match_submissions")
      .select("*")
      .eq("status", "pending");

    if (error) throw new Error(`could not read manual_match_submissions: ${error.message}`);

    return (data ?? []).map((row) => ({
      externalRef: row.external_ref,
      sportCode: row.sport_code,
      competition: row.competition,
      homeTeamName: row.home_team_name,
      awayTeamName: row.away_team_name,
      groundName: row.ground_name,
      playedAt: row.played_at,
      homeScore: row.home_score,
      awayScore: row.away_score,
    }));
  },

  async afterUpsert(results: { raw: RawProviderMatch; result: UpsertResult }[], _ctx: ProviderContext): Promise<void> {
    if (results.length === 0) return;
    const supabase = createAdminClient();
    const now = new Date().toISOString();

    await Promise.all(
      results.map(({ raw, result }) => {
        if (result.outcome === "skipped") {
          return supabase
            .from("manual_match_submissions")
            .update({ status: "error", error_message: result.reason ?? "skipped" })
            .eq("external_ref", raw.externalRef);
        }
        return supabase
          .from("manual_match_submissions")
          .update({ status: "applied", applied_at: now, error_message: null })
          .eq("external_ref", raw.externalRef);
      }),
    );
  },
};
