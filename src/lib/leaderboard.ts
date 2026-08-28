import { supabase } from './supabaseClient'
import { fetchAllRows } from './fetchAllRows'
import { tierForHomeMatchCount, type Tier } from './achievements'
import type { Enums } from './database.types'

// Re-exported so existing importers (Leaderboard.tsx) don't need to change
// -- the medal-tier logic itself now lives in achievements.ts since
// Achievements.tsx/Profile.tsx need it too, not just the leaderboard.
export { tierForHomeMatchCount }
export type { Tier }

export type Province = Enums<'province'>
export type SportCode = Enums<'sport_code'>
export type SportFilter = SportCode | 'combined'

export type LeaderboardEntry = {
  id: string
  displayName: string
  matchCount: number
  groundCount: number
  provinceMatchCounts: Record<string, number>
  tierCounts: Record<Tier, number>
  supportedCountyId: string | null
  // Matches attended (home or away, either sport unless a sport filter is
  // applied) involving this entry's OWN supported county specifically --
  // distinct from matchCount, which is every match they've ever attended
  // regardless of county. The "My County" tab filters the leaderboard down
  // to a county's supporters, but without this it was still ranking/
  // displaying them by their overall match count, not by how engaged they
  // actually are with that county.
  supportedCountyMatchCount: number
}

const teamKey = (countyId: string, sportCode: string) => `${countyId}:${sportCode}`

type ProfileRow = {
  id: string
  display_name: string | null
  is_premium: boolean
  leaderboard_opt_in: boolean
  supported_county_id: string | null
}
type AttendanceRow = { user_id: string; match_id: string }
type VisitRow = { user_id: string; ground_id: string }
type MatchRow = { id: string; home_county_team_id: string | null; away_county_team_id: string | null; ground_id: string | null }
type CountyTeamRow = { id: string; county_id: string; sport_code: string }
type CountyRow = { id: string; name: string; province: string }
type GroundRow = { id: string; county_id: string }
type UserAchievementRow = { user_id: string; achievement_id: string }
type AchievementDefRow = { id: string; rule_type: string; rule_params: unknown }

export type LeaderboardRawData = {
  profileById: Map<string, ProfileRow>
  attendance: AttendanceRow[]
  visits: VisitRow[]
  matchById: Map<string, MatchRow>
  teamToCounty: Map<string, string>
  teamSport: Map<string, string>
  countyToProvince: Map<string, string>
  groundCounty: Map<string, string>
  matchProvinces: Map<string, Set<string>>
  // A match's own sport, resolved from either team the same way
  // Matches.tsx resolves a MatchCard's sportCode -- a match has no
  // sport_code column of its own, only its participating teams do.
  matchSport: Map<string, string>
  userAchievements: UserAchievementRow[]
  defById: Map<string, AchievementDefRow>
}

/**
 * Fetches every table loadLeaderboardEntries needs, once. Kept separate
 * from the aggregation step so switching the sport filter (combined/
 * football/hurling) on the Leaderboard page can recompute entries
 * instantly from already-fetched data instead of re-querying Supabase on
 * every tap.
 */
export async function fetchLeaderboardRawData(): Promise<LeaderboardRawData> {
  // `matches`, `attendance`, `visits`, and `userAchievements` all grow
  // without bound as the app is used (matches with every fixture import,
  // the others with every check-in) -- a plain .select() silently truncates
  // at PostgREST's default 1000-row cap once any of them cross that, which
  // is exactly what happened here: `matches` passed 8,000 rows and recent
  // fixtures started dropping out of every leaderboard calculation that
  // touches match data, not just the "My County" count that surfaced it.
  // county_teams/counties/grounds/achievement_definitions are small,
  // slow-growing reference tables (a few hundred rows at most) with no
  // realistic path to 1000, so a plain select stays fine for those.
  const [profiles, attendance, visits, matches, countyTeams, counties, grounds, userAchievements, achievementDefs] =
    await Promise.all([
      fetchAllRows<ProfileRow>('user_profiles', 'id, display_name, is_premium, leaderboard_opt_in, supported_county_id'),
      fetchAllRows<AttendanceRow>('user_match_attendance', 'user_id, match_id'),
      fetchAllRows<VisitRow>('user_visits', 'user_id, ground_id'),
      fetchAllRows<MatchRow>('matches', 'id, home_county_team_id, away_county_team_id, ground_id'),
      supabase.from('county_teams').select('id, county_id, sport_code').then((r) => r.data as CountyTeamRow[] | null),
      supabase.from('counties').select('id, name, province').then((r) => r.data as CountyRow[] | null),
      supabase.from('grounds').select('id, county_id').then((r) => r.data as GroundRow[] | null),
      fetchAllRows<UserAchievementRow>('user_achievements', 'user_id, achievement_id'),
      supabase.from('achievement_definitions').select('id, rule_type, rule_params').then((r) => r.data as AchievementDefRow[] | null),
    ])

  const teamToCounty = new Map((countyTeams ?? []).map((t) => [t.id, t.county_id]))
  const teamSport = new Map((countyTeams ?? []).map((t) => [t.id, t.sport_code]))
  const countyToProvince = new Map((counties ?? []).map((c) => [c.id, c.province]))
  const groundCounty = new Map((grounds ?? []).map((g) => [g.id, g.county_id]))
  const matchById = new Map((matches ?? []).map((m) => [m.id, m]))

  const matchProvinces = new Map<string, Set<string>>()
  const matchSport = new Map<string, string>()
  for (const m of matches ?? []) {
    const provs = new Set<string>()
    let sport: string | undefined
    for (const teamId of [m.home_county_team_id, m.away_county_team_id]) {
      if (!teamId) continue
      const countyId = teamToCounty.get(teamId)
      const province = countyId ? countyToProvince.get(countyId) : undefined
      if (province) provs.add(province)
      sport = sport ?? teamSport.get(teamId)
    }
    matchProvinces.set(m.id, provs)
    if (sport) matchSport.set(m.id, sport)
  }

  return {
    profileById: new Map((profiles ?? []).map((p) => [p.id, p])),
    attendance,
    visits,
    matchById,
    teamToCounty,
    teamSport,
    countyToProvince,
    groundCounty,
    matchProvinces,
    matchSport,
    userAchievements,
    defById: new Map((achievementDefs ?? []).map((d) => [d.id, d])),
  }
}

/**
 * Computes every signed-in-visible leaderboard entry in one pass, mirroring
 * LeaderboardView.swift's load(): overall + per-province match counts,
 * distinct ground counts, and county_home_match/county_away_match tier
 * tallies (bronze/silver/gold) for the "Most Bronze"/"Most Silver"/"Top
 * Gold" tabs. Only profiles with is_premium AND leaderboard_opt_in are
 * included -- premium alone isn't consent to publish someone's name/stats.
 *
 * `sportFilter` restricts every match-based count (matchCount,
 * provinceMatchCounts, supportedCountyMatchCount, tierCounts) to that one
 * sport; 'combined' (the default) counts both. groundCount is always
 * combined regardless -- a ground visit has no reliable link back to which
 * match/sport it was for, so there's nothing sport-specific to filter it by.
 */
export function buildLeaderboardEntries(raw: LeaderboardRawData, sportFilter: SportFilter = 'combined'): LeaderboardEntry[] {
  const { profileById, matchById, teamToCounty, groundCounty, matchProvinces, matchSport, defById } = raw

  const attendance =
    sportFilter === 'combined' ? raw.attendance : raw.attendance.filter((a) => matchSport.get(a.match_id) === sportFilter)

  const overallMatchCounts = new Map<string, number>()
  const provinceCounts = new Map<string, Map<string, number>>()
  for (const a of attendance) {
    overallMatchCounts.set(a.user_id, (overallMatchCounts.get(a.user_id) ?? 0) + 1)
    for (const province of matchProvinces.get(a.match_id) ?? []) {
      const byUser = provinceCounts.get(province) ?? new Map<string, number>()
      byUser.set(a.user_id, (byUser.get(a.user_id) ?? 0) + 1)
      provinceCounts.set(province, byUser)
    }
  }

  const groundIdsByUser = new Map<string, Set<string>>()
  for (const v of raw.visits) {
    const set = groundIdsByUser.get(v.user_id) ?? new Set<string>()
    set.add(v.ground_id)
    groundIdsByUser.set(v.user_id, set)
  }

  // Home/road match counts per user, per (county, sport) -- same basis
  // county_home_match/county_away_match achievements are tiered on.
  const homeCounts = new Map<string, number>()
  const roadCounts = new Map<string, number>()
  for (const a of attendance) {
    const match = matchById.get(a.match_id)
    const groundId = match?.ground_id
    const groundCountyId = groundId ? groundCounty.get(groundId) : undefined
    if (!match || !groundCountyId) continue
    for (const teamId of [match.home_county_team_id, match.away_county_team_id]) {
      if (!teamId) continue
      const countyId = teamToCounty.get(teamId)
      const sportCode = raw.teamSport.get(teamId)
      if (!countyId || !sportCode) continue
      const key = `${a.user_id}:${teamKey(countyId, sportCode)}`
      if (countyId === groundCountyId) {
        homeCounts.set(key, (homeCounts.get(key) ?? 0) + 1)
      } else {
        roadCounts.set(key, (roadCounts.get(key) ?? 0) + 1)
      }
    }
  }

  const tierCountsByUser = new Map<string, Record<Tier, number>>()
  for (const ua of raw.userAchievements) {
    const def = defById.get(ua.achievement_id)
    if (!def || (def.rule_type !== 'county_home_match' && def.rule_type !== 'county_away_match')) continue
    const params = (def.rule_params ?? {}) as Record<string, unknown>
    const countyId = params.county_id as string | undefined
    const sportCode = params.sport_code as string | undefined
    if (!countyId || !sportCode) continue
    if (sportFilter !== 'combined' && sportCode !== sportFilter) continue
    const key = `${ua.user_id}:${teamKey(countyId, sportCode)}`
    const count = def.rule_type === 'county_home_match' ? (homeCounts.get(key) ?? 0) : (roadCounts.get(key) ?? 0)
    const tier = tierForHomeMatchCount(count)
    if (tier === 'standard') continue
    const bucket = tierCountsByUser.get(ua.user_id) ?? { bronze: 0, silver: 0, gold: 0 }
    bucket[tier] += 1
    tierCountsByUser.set(ua.user_id, bucket)
  }

  const allIds = new Set([...overallMatchCounts.keys(), ...groundIdsByUser.keys()])

  // For each attended match, credit it to the attendee's supported-county
  // tally only if one of the two teams actually belongs to their county --
  // computed per-user (not globally per county) since every user has their
  // own supported county to check against.
  const supportedCountyMatchCounts = new Map<string, number>()
  for (const a of attendance) {
    const supportedCountyId = profileById.get(a.user_id)?.supported_county_id
    if (!supportedCountyId) continue
    const match = matchById.get(a.match_id)
    if (!match) continue
    const involvesSupportedCounty = [match.home_county_team_id, match.away_county_team_id].some(
      (teamId) => teamId && teamToCounty.get(teamId) === supportedCountyId,
    )
    if (involvesSupportedCounty) {
      supportedCountyMatchCounts.set(a.user_id, (supportedCountyMatchCounts.get(a.user_id) ?? 0) + 1)
    }
  }

  const entries: LeaderboardEntry[] = []
  for (const uid of allIds) {
    const profile = profileById.get(uid)
    if (!profile || !profile.is_premium || !profile.leaderboard_opt_in) continue
    const provinceMatchCounts: Record<string, number> = {}
    for (const [province, byUser] of provinceCounts) {
      provinceMatchCounts[province] = byUser.get(uid) ?? 0
    }
    entries.push({
      id: uid,
      displayName: profile.display_name ?? 'Anonymous',
      matchCount: overallMatchCounts.get(uid) ?? 0,
      groundCount: groundIdsByUser.get(uid)?.size ?? 0,
      provinceMatchCounts,
      tierCounts: tierCountsByUser.get(uid) ?? { bronze: 0, silver: 0, gold: 0 },
      supportedCountyId: profile.supported_county_id,
      supportedCountyMatchCount: supportedCountyMatchCounts.get(uid) ?? 0,
    })
  }

  return entries
}

/** Convenience wrapper for callers that don't need to hold onto the raw data (e.g. Achievements.tsx, if ever used elsewhere). */
export async function loadLeaderboardEntries(sportFilter: SportFilter = 'combined'): Promise<LeaderboardEntry[]> {
  const raw = await fetchLeaderboardRawData()
  return buildLeaderboardEntries(raw, sportFilter)
}
