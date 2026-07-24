import type { MatchDataProvider, ProviderContext, RawProviderMatch } from "../shared/types.ts";

/**
 * ClubZap adapter — SCAFFOLD, not a working integration. Same situation as
 * providers/scorebeo.ts: no API docs or credentials to build a real
 * integration against, so this is structured to be filled in later rather
 * than left unimplemented.
 *
 * To activate: set CLUBZAP_API_KEY (and CLUBZAP_BASE_URL if needed) as
 * Edge Function secrets, replace the fetchUpdates() body with the real call
 * + mapping, flip data_providers.enabled for 'clubzap' to true.
 */
export const clubzapProvider: MatchDataProvider = {
  code: "clubzap",

  async fetchUpdates(_sinceIso: string | null, _ctx: ProviderContext): Promise<RawProviderMatch[]> {
    const apiKey = Deno.env.get("CLUBZAP_API_KEY");
    if (!apiKey) {
      console.log("[clubzap] CLUBZAP_API_KEY not set — skipping (not yet licensed/configured)");
      return [];
    }

    // TODO once licensed: replace with the real ClubZap endpoint + mapping.
    console.log("[clubzap] adapter not yet implemented — see comments in providers/clubzap.ts");
    return [];
  },
};
