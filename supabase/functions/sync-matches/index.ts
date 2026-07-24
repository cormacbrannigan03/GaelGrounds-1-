// sync-matches — the ingestion orchestrator.
//
// This is the only Edge Function in the pipeline. It knows nothing about
// ScoreBeo, ClubZap, CSVs, or manual entry specifically — it reads the
// `data_providers` registry table, dispatches to whichever adapters are
// enabled via providers/registry.ts, and funnels everything they return
// through the same normalize.ts upsert. That indirection is the whole
// point: replacing a provider, or adding a new one, never touches this
// file, the app, or any other provider.
//
// Invocation:
//   POST /functions/v1/sync-matches                    → run every enabled, cron-scheduled provider
//   POST /functions/v1/sync-matches?provider=csv&file=x → run one provider on demand (e.g. a CSV import)
//   POST /functions/v1/sync-matches?provider=manual     → just process pending manual submissions
//
// Auth: this function is deployed with verify_jwt=false (it's invoked by
// pg_cron, not a signed-in user) and instead checks the `x-sync-secret`
// header against the SYNC_SECRET Edge Function secret. See ../../README.md
// for how that secret is set up.

import { createAdminClient } from "./shared/supabaseAdmin.ts";
import { upsertMatch } from "./shared/normalize.ts";
import { providerRegistry } from "./providers/registry.ts";
import type { RawProviderMatch, UpsertResult } from "./shared/types.ts";

interface ProviderRow {
  code: string;
  enabled: boolean;
  run_in_scheduled_sync: boolean;
  config: Record<string, unknown>;
  last_synced_at: string | null;
}

Deno.serve(async (req) => {
  const expectedSecret = Deno.env.get("SYNC_SECRET");
  const providedSecret = req.headers.get("x-sync-secret");
  if (expectedSecret && providedSecret !== expectedSecret) {
    return json({ error: "unauthorized" }, 401);
  }

  const url = new URL(req.url);
  const params = url.searchParams;
  const requestedProvider = params.get("provider");
  const triggeredBy: "cron" | "manual" | "api" = params.has("cron") ? "cron" : requestedProvider ? "api" : "manual";

  const supabase = createAdminClient();

  let providerRows: ProviderRow[];
  if (requestedProvider) {
    const { data, error } = await supabase.from("data_providers").select("*").eq("code", requestedProvider);
    if (error) return json({ error: error.message }, 500);
    providerRows = data ?? [];
    if (providerRows.length === 0) return json({ error: `unknown provider "${requestedProvider}"` }, 404);
  } else {
    const { data, error } = await supabase
      .from("data_providers")
      .select("*")
      .eq("enabled", true)
      .eq("run_in_scheduled_sync", true);
    if (error) return json({ error: error.message }, 500);
    providerRows = data ?? [];
  }

  const summaries = [];
  for (const providerRow of providerRows) {
    summaries.push(await runProvider(supabase, providerRow, params, triggeredBy));
  }

  return json({ ranAt: new Date().toISOString(), providers: summaries });
});

async function runProvider(
  supabase: ReturnType<typeof createAdminClient>,
  providerRow: ProviderRow,
  params: URLSearchParams,
  triggeredBy: "cron" | "manual" | "api",
) {
  const adapter = providerRegistry[providerRow.code];
  if (!adapter) {
    return { provider: providerRow.code, status: "error", error: "no adapter registered for this provider code" };
  }
  if (!providerRow.enabled) {
    return { provider: providerRow.code, status: "skipped", reason: "disabled" };
  }

  const { data: run } = await supabase
    .from("data_sync_runs")
    .insert({ provider_code: providerRow.code, triggered_by: triggeredBy })
    .select("id")
    .single();

  const counts = { created: 0, updated: 0, unchanged: 0, skipped: 0 };
  const skippedReasons: string[] = [];

  try {
    const raw = await adapter.fetchUpdates(providerRow.last_synced_at, { config: providerRow.config, params });

    const results: { raw: RawProviderMatch; result: UpsertResult }[] = [];
    for (const match of raw) {
      const result = await upsertMatch(supabase, providerRow.code, match);
      results.push({ raw: match, result });
      counts[result.outcome]++;
      if (result.outcome === "skipped" && result.reason) skippedReasons.push(result.reason);
    }

    if (adapter.afterUpsert) {
      await adapter.afterUpsert(results, { config: providerRow.config, params });
    }

    await supabase
      .from("data_providers")
      .update({ last_synced_at: new Date().toISOString() })
      .eq("code", providerRow.code);

    if (run) {
      await supabase
        .from("data_sync_runs")
        .update({
          finished_at: new Date().toISOString(),
          status: "success",
          matches_created: counts.created,
          matches_updated: counts.updated,
          matches_unchanged: counts.unchanged,
          matches_skipped: counts.skipped,
        })
        .eq("id", run.id);
    }

    return { provider: providerRow.code, status: "success", counts, skippedReasons: skippedReasons.slice(0, 20) };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    if (run) {
      await supabase
        .from("data_sync_runs")
        .update({ finished_at: new Date().toISOString(), status: "error", error_message: message, ...counts })
        .eq("id", run.id);
    }
    return { provider: providerRow.code, status: "error", error: message };
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });
}
