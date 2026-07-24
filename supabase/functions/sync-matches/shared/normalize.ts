import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { RawProviderMatch, UpsertResult } from "./types.ts";

/**
 * Resolve a provider's free-text county name to a county_teams.id for the
 * given sport. Tries the alias table first (fast, curatable), falls back to
 * a case-insensitive exact match against counties.name, and — if the
 * fallback worked — remembers it as an alias so next time is a single
 * indexed lookup instead of two round trips.
 */
export async function resolveCountyTeamId(
  supabase: SupabaseClient,
  providerCode: string,
  teamName: string,
  sportCode: string,
): Promise<string | null> {
  const trimmed = teamName.trim();
  if (!trimmed) return null;

  const { data: alias } = await supabase
    .from("provider_team_aliases")
    .select("county_team_id")
    .eq("provider_code", providerCode)
    .eq("external_name", trimmed)
    .maybeSingle();
  if (alias) return alias.county_team_id as string;

  const { data: county } = await supabase
    .from("counties")
    .select("id")
    .ilike("name", trimmed)
    .maybeSingle();
  if (!county) return null;

  const { data: team } = await supabase
    .from("county_teams")
    .select("id")
    .eq("county_id", county.id)
    .eq("sport_code", sportCode)
    .maybeSingle();
  if (!team) return null;

  await supabase
    .from("provider_team_aliases")
    .insert({ provider_code: providerCode, external_name: trimmed, county_team_id: team.id })
    .then(() => undefined, () => undefined); // best-effort — a race on the unique key is fine, ignore it

  return team.id as string;
}

export async function resolveGroundId(
  supabase: SupabaseClient,
  providerCode: string,
  groundName: string,
): Promise<string | null> {
  const trimmed = groundName.trim();
  if (!trimmed) return null;

  const { data: alias } = await supabase
    .from("provider_ground_aliases")
    .select("ground_id")
    .eq("provider_code", providerCode)
    .eq("external_name", trimmed)
    .maybeSingle();
  if (alias) return alias.ground_id as string;

  const { data: ground } = await supabase
    .from("grounds")
    .select("id")
    .ilike("name", trimmed)
    .maybeSingle();
  if (!ground) return null;

  await supabase
    .from("provider_ground_aliases")
    .insert({ provider_code: providerCode, external_name: trimmed, ground_id: ground.id })
    .then(() => undefined, () => undefined);

  return ground.id as string;
}

/**
 * Idempotently write one provider match into `matches`, keyed on
 * (source_provider, source_ref). Every provider funnels through this same
 * function — it's the one place that knows how a RawProviderMatch becomes a
 * `matches` row, so every provider gets identical dedup, name-resolution,
 * and change-detection behaviour for free.
 */
export async function upsertMatch(
  supabase: SupabaseClient,
  providerCode: string,
  raw: RawProviderMatch,
): Promise<UpsertResult> {
  const homeCountyTeamId = await resolveCountyTeamId(supabase, providerCode, raw.homeTeamName, raw.sportCode);
  const awayCountyTeamId = await resolveCountyTeamId(supabase, providerCode, raw.awayTeamName, raw.sportCode);

  if (!homeCountyTeamId || !awayCountyTeamId) {
    return {
      outcome: "skipped",
      reason: `could not resolve team(s): "${raw.homeTeamName}" / "${raw.awayTeamName}" (${raw.sportCode})`,
    };
  }

  const groundId = raw.groundName ? await resolveGroundId(supabase, providerCode, raw.groundName) : null;

  const { data: existing } = await supabase
    .from("matches")
    .select("id, home_score, away_score, played_at, competition, ground_id")
    .eq("source_provider", providerCode)
    .eq("source_ref", raw.externalRef)
    .maybeSingle();

  const row = {
    match_type: "county" as const,
    home_county_team_id: homeCountyTeamId,
    away_county_team_id: awayCountyTeamId,
    ground_id: groundId,
    competition: raw.competition,
    played_at: raw.playedAt,
    home_score: raw.homeScore ?? null,
    away_score: raw.awayScore ?? null,
    source_provider: providerCode,
    source_ref: raw.externalRef,
    source_synced_at: new Date().toISOString(),
  };

  if (!existing) {
    const { error } = await supabase.from("matches").insert(row);
    if (error) return { outcome: "skipped", reason: error.message };
    return { outcome: "created" };
  }

  const changed =
    existing.home_score !== row.home_score ||
    existing.away_score !== row.away_score ||
    existing.played_at !== row.played_at ||
    existing.competition !== row.competition ||
    existing.ground_id !== row.ground_id;

  if (!changed) {
    // Still bump source_synced_at so staleness is observable, but skip the
    // score/competition/etc write — no point firing a realtime update (and
    // waking every subscribed client) for a row that hasn't actually moved.
    await supabase.from("matches").update({ source_synced_at: row.source_synced_at }).eq("id", existing.id);
    return { outcome: "unchanged" };
  }

  const { error } = await supabase.from("matches").update(row).eq("id", existing.id);
  if (error) return { outcome: "skipped", reason: error.message };
  return { outcome: "updated" };
}
