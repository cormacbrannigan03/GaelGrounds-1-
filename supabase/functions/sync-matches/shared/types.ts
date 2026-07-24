// The provider interface — this is the seam the whole architecture hangs
// off. Every data source (ScoreBeo, ClubZap, a CSV upload, hand-entered
// rows) implements this one interface and nothing else in the system knows
// or cares which. Swapping ScoreBeo for a different fixtures API means
// writing one new file and changing one row in `data_providers` — nothing
// in normalize.ts, index.ts, or the app changes.

export type SportCode = "gaelic_football" | "hurling" | "camogie" | "ladies_football";

/** A match as reported by a provider, before we've resolved team/ground names to our UUIDs. */
export interface RawProviderMatch {
  /** Stable id from the provider's own system — the idempotency key we upsert on. */
  externalRef: string;
  sportCode: SportCode;
  competition: string;
  /** County name as the provider spells it, e.g. "Dublin", "Dublin GAA". Resolved via provider_team_aliases. */
  homeTeamName: string;
  awayTeamName: string;
  /** Venue name as the provider spells it. Optional — some fixture feeds don't confirm a venue in advance. */
  groundName?: string | null;
  /** ISO 8601. */
  playedAt: string;
  /** GAA score notation, e.g. "1-14". Omit/null for a fixture that hasn't been played yet. */
  homeScore?: string | null;
  awayScore?: string | null;
}

/** Non-secret config from data_providers.config, plus request-scoped extras (e.g. a CSV file path). */
export interface ProviderContext {
  config: Record<string, unknown>;
  params: URLSearchParams;
}

export type UpsertOutcome = "created" | "updated" | "unchanged" | "skipped";

export interface UpsertResult {
  outcome: UpsertOutcome;
  reason?: string;
}

export interface MatchDataProvider {
  code: string;
  /**
   * Return every match the provider has that's new or changed since the
   * cursor. Providers that can't filter server-side are free to ignore
   * `sinceIso` and return everything — normalize.ts's upsert is a no-op for
   * anything that hasn't actually changed, so over-fetching is safe, just
   * wasteful.
   */
  fetchUpdates(sinceIso: string | null, ctx: ProviderContext): Promise<RawProviderMatch[]>;

  /**
   * Optional: called once per sync with the upsert outcome for every match
   * this provider returned. Providers backed by their own staging table
   * (like `manual`, which tracks pending/applied/error) use this to close
   * the loop; stateless API providers simply don't implement it.
   */
  afterUpsert?(results: { raw: RawProviderMatch; result: UpsertResult }[], ctx: ProviderContext): Promise<void>;
}
