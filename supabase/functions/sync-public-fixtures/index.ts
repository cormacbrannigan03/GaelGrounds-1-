import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

type Sport = "gaelic_football" | "hurling";
type Fixture = {
  ref: string; url: string; sport: Sport; competition: string; season: number;
  round: string | null; home: string; away: string; venue: string | null;
  date: string; time: string; homeScore: string | null; awayScore: string | null;
};
type Source = {
  name: string; url: string; format: "ical" | "jsonld";
  sport?: Sport; competition?: string;
};

const EXCLUDED = /\b(ladies|camogie|minor|u-?20|under[- ]?20|u-?21|club|schools?)\b/i;
const AGENT = "GaelGrounds/1.0 public fixture sync";

Deno.serve(async (req) => {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({ error: "missing Supabase environment" }, 500);
  const db = createClient(url, key, { auth: { persistSession: false } });
  const requestUrl = new URL(req.url);
  const season = Number(requestUrl.searchParams.get("season") ?? new Date().getUTCFullYear());
  const dryRun = requestUrl.searchParams.get("dry_run") === "1";

  const { data: provider } = await db.from("data_providers").select("enabled,config")
    .eq("code", "public_sources").maybeSingle();
  const config = (provider?.config ?? {}) as {
    rteEnabled?: boolean; sources?: Source[]; syncSecretSha256?: string;
  };
  const supplied = req.headers.get("x-sync-secret") ?? "";
  const environmentSecret = Deno.env.get("SYNC_SECRET");
  const authorized = environmentSecret
    ? supplied === environmentSecret
    : Boolean(config.syncSecretSha256) && await sha256(supplied) === config.syncSecretSha256;
  if (!authorized) return json({ error: "unauthorized" }, 401);
  if (!provider?.enabled) return json({ error: "provider disabled" }, 503);
  const fixtures: Fixture[] = [];
  const sources: Record<string, unknown>[] = [];

  if (config.rteEnabled !== false) {
    try {
      const rows = await fetchRte(season);
      fixtures.push(...rows);
      sources.push({ name: "RTÉ", status: "success", fixtures: rows.length });
    } catch (error) {
      sources.push({ name: "RTÉ", status: "error", error: message(error) });
    }
  }
  for (const source of config.sources ?? []) {
    try {
      const rows = source.format === "ical"
        ? await fetchIcal(source, season)
        : await fetchJsonLd(source, season);
      fixtures.push(...rows);
      sources.push({ name: source.name, status: "success", fixtures: rows.length });
    } catch (error) {
      sources.push({ name: source.name, status: "error", error: message(error) });
    }
  }

  const unique = new Map<string, Fixture>();
  for (const row of fixtures) if (!EXCLUDED.test(row.competition)) unique.set(row.ref, row);
  const counts = { created: 0, updated: 0, unchanged: 0, skipped: 0 };
  const skipped: string[] = [];
  if (!dryRun) {
    const pending = [...unique.values()];
    for (let offset = 0; offset < pending.length; offset += 10) {
      const batch = await Promise.all(pending.slice(offset, offset + 10).map((fixture) => upsert(db, fixture)));
      for (const result of batch) {
        counts[result.outcome]++;
        if (result.reason && skipped.length < 30) skipped.push(result.reason);
      }
    }
    await db.from("data_providers").update({ last_synced_at: new Date().toISOString() })
      .eq("code", "public_sources");
  }
  return json({ ranAt: new Date().toISOString(), season, dryRun, discovered: unique.size, counts, skipped, sources });
});

async function fetchRte(season: number): Promise<Fixture[]> {
  const index = await fetchText("https://www.rte.ie/sport/results/gaa/");
  const root = `https://www.rte.ie/sport/results/gaa/${season}/`;
  const competitions = new Map<string, string>();
  const links = new RegExp(`href=["']/sport/results/gaa/${season}/(\\d+)/(?:fixtures|results)/["'][^>]*>([\\s\\S]*?)</a>`, "gi");
  for (const match of index.matchAll(links)) {
    const title = strip(match[2]);
    if (title && !EXCLUDED.test(title)) competitions.set(match[1], title);
  }

  const pages = await Promise.all(
    [...competitions].flatMap(([id, indexTitle]) =>
      ["fixtures", "results"].map(async (kind) => {
      const page = `${root}${id}/${kind}/`;
      const html = await fetchText(page);
      const heading = strip(html.match(/class="[^"]*index-heading[^"]*"[^>]*>([\s\S]*?)<\/h1>/i)?.[1] ?? indexTitle);
        return parseRte(html, page, id, heading, season);
      })
    )
  );
  return pages.flat();
}

function parseRte(html: string, url: string, competitionId: string, rawTitle: string, season: number): Fixture[] {
  const competition = canonicalCompetition(rawTitle);
  const sport = inferSport(competition);
  if (!sport) return [];
  const rows: Fixture[] = [];
  const starts = [...html.matchAll(/<div class="match-item[^"]*"[^>]*data-matchID="([^"]+)"[^>]*>/gi)];
  for (let index = 0; index < starts.length; index++) {
    const start = starts[index];
    const body = html.slice(start.index!, starts[index + 1]?.index ?? html.length);
    const home = team(body, "home");
    const away = team(body, "away");
    const date = dayMonth(strip(capture(body, /class="match-heading match-startdate"[^>]*>([\s\S]*?)<\/span>/i)), season);
    if (!home || !away || !date) continue;
    const status = strip(capture(body, /class="match-heading match-time-status"[^>]*>([\s\S]*?)<\/span>/i));
    const clock = status.match(/\b([01]?\d|2[0-3])[:.]([0-5]\d)\b/);
    const time = clock ? `${clock[1].padStart(2, "0")}:${clock[2]}:00` : estimatedTime(date);
    const scores = [...strip(capture(body, /class="match-main-info"[^>]*>([\s\S]*?)<\/p>/i))
      .matchAll(/(\d+\s*[-–]\s*\d+)/g)].map((item) => item[1].replace(/[–\s]/g, (v) => v === "–" ? "-" : ""));
    rows.push({
      ref: `rte:${competitionId}:${start[1]}`, url, sport, competition, season,
      round: strip(capture(body, /class="match-heading match-group"[^>]*>([\s\S]*?)<\/span>/i)) || null,
      home: canonicalTeam(home), away: canonicalTeam(away),
      venue: strip(capture(body, /class="match-footer"[^>]*>[\s\S]*?<p[^>]*>([\s\S]*?)<\/p>/i)) || null,
      date, time, homeScore: scores[0] ?? null, awayScore: scores[1] ?? null,
    });
  }
  return rows;
}

async function fetchIcal(source: Source, season: number): Promise<Fixture[]> {
  const text = (await fetchText(source.url)).replace(/\r?\n[ \t]/g, "");
  const rows: Fixture[] = [];
  for (const event of text.matchAll(/BEGIN:VEVENT([\s\S]*?)END:VEVENT/g)) {
    const fields: Record<string, string> = {};
    for (const line of event[1].split(/\r?\n/)) {
      const at = line.indexOf(":");
      if (at > 0) fields[line.slice(0, at).split(";")[0]] = line.slice(at + 1).replace(/\\,/g, ",");
    }
    const start = fields.DTSTART?.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2}))?/);
    const teams = fields.SUMMARY?.split(/\s+(?:v|vs\.?|versus)\s+/i).map((v) => v.trim());
    if (!start || Number(start[1]) !== season || teams?.length !== 2 || !source.sport || !source.competition) continue;
    const date = `${start[1]}-${start[2]}-${start[3]}`;
    rows.push({
      ref: `${source.name}:ical:${fields.UID ?? `${date}:${teams.join(":")}`}`,
      url: fields.URL ?? source.url, sport: source.sport,
      competition: canonicalCompetition(source.competition), season, round: null,
      home: canonicalTeam(teams[0]), away: canonicalTeam(teams[1]),
      venue: fields.LOCATION ?? null, date,
      time: start[4] ? `${start[4]}:${start[5]}:00` : estimatedTime(date),
      homeScore: null, awayScore: null,
    });
  }
  return rows;
}

async function fetchJsonLd(source: Source, season: number): Promise<Fixture[]> {
  const html = await fetchText(source.url);
  const rows: Fixture[] = [];
  for (const script of html.matchAll(/<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)) {
    let parsed: unknown;
    try { parsed = JSON.parse(decode(script[1])); } catch { continue; }
    for (const event of events(parsed)) {
      const start = typeof event.startDate === "string" ? new Date(event.startDate) : null;
      const home = named(event.homeTeam ?? event.competitor?.[0]);
      const away = named(event.awayTeam ?? event.competitor?.[1]);
      if (!start || Number.isNaN(start.valueOf()) || start.getUTCFullYear() !== season ||
          !home || !away || !source.sport || !source.competition) continue;
      const date = start.toISOString().slice(0, 10);
      rows.push({
        ref: `${source.name}:jsonld:${event.identifier ?? event.url ?? `${date}:${home}:${away}`}`,
        url: String(event.url ?? source.url), sport: source.sport,
        competition: canonicalCompetition(source.competition), season, round: null,
        home: canonicalTeam(home), away: canonicalTeam(away), venue: named(event.location) || null,
        date, time: `${String(start.getUTCHours()).padStart(2, "0")}:${String(start.getUTCMinutes()).padStart(2, "0")}:00`,
        homeScore: null, awayScore: null,
      });
    }
  }
  return rows;
}

async function upsert(db: SupabaseClient, f: Fixture): Promise<{ outcome: keyof typeof COUNTS; reason?: string }> {
  const homeId = await teamId(db, f.home, f.sport);
  const awayId = await teamId(db, f.away, f.sport);
  if (!homeId || !awayId) return { outcome: "skipped", reason: `Unresolved teams: ${f.home} / ${f.away}` };
  const competitionId = await compId(db, f.competition, f.sport);
  if (!competitionId) return { outcome: "skipped", reason: `Unresolved competition: ${f.competition}` };
  const groundId = f.venue ? await venueId(db, f.venue) : null;

  let { data: existing } = await db.from("matches")
    .select("id,home_score,away_score,match_date,throw_in_time,ground_id,competition_id,status,source_provider,source_ref")
    .eq("source_provider", "public_sources").eq("source_ref", f.ref).maybeSingle();
  if (!existing) {
    const found = await db.from("matches")
      .select("id,home_score,away_score,match_date,throw_in_time,ground_id,competition_id,status,source_provider,source_ref")
      .eq("match_date", f.date)
      .or(`and(home_county_team_id.eq.${homeId},away_county_team_id.eq.${awayId}),and(home_county_team_id.eq.${awayId},away_county_team_id.eq.${homeId})`)
      .maybeSingle();
    existing = found.data;
  }

  const homeScore = f.homeScore ?? existing?.home_score ?? null;
  const awayScore = f.awayScore ?? existing?.away_score ?? null;
  const row = {
    match_type: "county", home_county_team_id: homeId, away_county_team_id: awayId,
    ground_id: groundId ?? existing?.ground_id ?? null, competition: f.competition, competition_id: competitionId,
    season: f.season, round: f.round, match_date: f.date, throw_in_time: f.time,
    played_at: new Date(`${f.date}T${f.time}+00:00`).toISOString(),
    status: homeScore && awayScore ? "completed" : "scheduled",
    home_score: homeScore, away_score: awayScore, winner: winner(homeScore, awayScore),
    source_provider: "public_sources", source_ref: f.ref, source_synced_at: new Date().toISOString(),
  };
  if (!existing) {
    const { error } = await db.from("matches").insert(row);
    return error ? { outcome: "skipped", reason: error.message } : { outcome: "created" };
  }
  const changed = existing.home_score !== row.home_score || existing.away_score !== row.away_score ||
    existing.match_date !== row.match_date || existing.throw_in_time !== row.throw_in_time ||
    existing.ground_id !== row.ground_id || existing.competition_id !== row.competition_id ||
    existing.status !== row.status;
  if (!changed) {
    await db.from("matches").update({ source_synced_at: row.source_synced_at }).eq("id", existing.id);
    return { outcome: "unchanged" };
  }
  const updateRow = existing.source_provider === "public_sources"
    ? row
    : { ...row, source_provider: existing.source_provider, source_ref: existing.source_ref };
  const { error } = await db.from("matches").update(updateRow).eq("id", existing.id);
  return error ? { outcome: "skipped", reason: error.message } : { outcome: "updated" };
}

const COUNTS = { created: 0, updated: 0, unchanged: 0, skipped: 0 };
async function teamId(db: SupabaseClient, name: string, sport: Sport) {
  const { data: county } = await db.from("counties").select("id").ilike("name", name).maybeSingle();
  if (!county) return null;
  const { data } = await db.from("county_teams").select("id")
    .eq("county_id", county.id).eq("sport_code", sport).maybeSingle();
  return data?.id ?? null;
}
async function compId(db: SupabaseClient, name: string, sport: Sport) {
  const { data } = await db.from("competitions").select("id")
    .eq("name", name).eq("sport_code", sport).maybeSingle();
  if (data) return data.id;
  const alias = await db.from("provider_competition_aliases").select("competition_id")
    .eq("provider_code", "public_sources").ilike("external_name", name).maybeSingle();
  return alias.data?.competition_id ?? null;
}
async function venueId(db: SupabaseClient, name: string) {
  const alias = await db.from("provider_ground_aliases").select("ground_id")
    .eq("provider_code", "public_sources").ilike("external_name", name).maybeSingle();
  if (alias.data) return alias.data.ground_id;
  const direct = await db.from("grounds").select("id").ilike("name", name.split(",")[0].trim()).maybeSingle();
  return direct.data?.id ?? null;
}

function canonicalCompetition(value: string) {
  const title = decode(value).replace(/\s+/g, " ").trim();
  return ({
    "All-Ireland Football Championship": "All-Ireland Senior Football Championship",
    "All-Ireland Hurling Championship": "All-Ireland Senior Hurling Championship",
    "Munster Football Championship": "Munster Senior Football Championship",
    "Munster Hurling Championship": "Munster Senior Hurling Championship",
    "Leinster Football Championship": "Leinster Senior Football Championship",
    "Leinster Hurling Championship": "Leinster Senior Hurling Championship",
    "Connacht Football Championship": "Connacht Senior Football Championship",
    "Ulster Football Championship": "Ulster Senior Football Championship",
    "Allianz Football League": "National Football League",
    "Allianz Hurling League": "National Hurling League",
    "Nicky Rackard Cup": "Nickey Rackard Cup",
  } as Record<string, string>)[title] ?? title;
}
function inferSport(title: string): Sport | null {
  if (EXCLUDED.test(title)) return null;
  if (/hurling|joe mcdonagh|christy ring|nicky rackard|lory meagher/i.test(title)) return "hurling";
  if (/football|tailteann/i.test(title)) return "gaelic_football";
  return null;
}
function canonicalTeam(value: string) { return value === "Londonderry" ? "Derry" : decode(value).trim(); }
function team(body: string, side: "home" | "away") {
  return strip(capture(body, new RegExp(`class="team-name team-${side} hide-for-small-only"[^>]*>([\\s\\S]*?)<\\/span>`, "i")));
}
function dayMonth(value: string, year: number) {
  const found = value.match(/\b(\d{1,2})\s+([A-Za-z]{3,9})\b/);
  if (!found) return null;
  const month = ["jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"]
    .indexOf(found[2].slice(0, 3).toLowerCase());
  return month < 0 ? null : `${year}-${String(month + 1).padStart(2, "0")}-${found[1].padStart(2, "0")}`;
}
function estimatedTime(date: string) {
  const day = new Date(`${date}T12:00:00Z`).getUTCDay();
  return day === 0 ? "15:30:00" : day === 6 ? "19:00:00" : "19:30:00";
}
function winner(home: string | null, away: string | null) {
  if (!home || !away) return null;
  const total = (score: string) => { const [g, p] = score.split("-").map(Number); return g * 3 + p; };
  return total(home) > total(away) ? "home" : total(away) > total(home) ? "away" : "draw";
}
function events(value: unknown): Record<string, any>[] {
  if (Array.isArray(value)) return value.flatMap(events);
  if (!value || typeof value !== "object") return [];
  const item = value as Record<string, any>;
  return (String(item["@type"] ?? "").includes("SportsEvent") ? [item] : [])
    .concat(Object.values(item).flatMap(events));
}
function named(value: any) { return typeof value === "string" ? value : typeof value?.name === "string" ? value.name : ""; }
function capture(value: string, pattern: RegExp) { return value.match(pattern)?.[1] ?? ""; }
function strip(value: string) { return decode(value.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()); }
function decode(value: string) {
  return value.replace(/&#x27;|&apos;/gi, "'").replace(/&quot;/gi, '"')
    .replace(/&amp;/gi, "&").replace(/&nbsp;/gi, " ")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)));
}
async function fetchText(url: string) {
  const parsed = new URL(url);
  if (parsed.protocol !== "https:") throw new Error("only HTTPS sources are accepted");
  const response = await fetch(parsed, {
    headers: { "user-agent": AGENT, accept: "text/html,application/ld+json,text/calendar" },
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return response.text();
}
function message(error: unknown) { return error instanceof Error ? error.message : String(error); }
async function sha256(value: string) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body, null, 2), { status, headers: { "content-type": "application/json" } });
}
