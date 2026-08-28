import { supabase } from './supabaseClient'
import { fetchAllRows } from './fetchAllRows'
import type { Enums } from './database.types'

export type Province = Enums<'province'>
export type Tier = 'bronze' | 'silver' | 'gold'

export type LeaderboardEntry = {
  id: string
  displayName: string
  matchCount: number
  groundCount: number
  provinceMatchCounts: Record<string, number>
  tierCounts: Record<Tier, number>
  supportedCountyId: string | null
  // Matches attended (home or away, either sport) involving this entry's
  // OWN supported county specifically -- distinct from matchCount, which is
  // every match they've ever attended regardless of county. The "My
  // County" tab filters the leaderboard down to a county's supporters, but
  // without this it was still ranking/displaying them by their overall
  // match count, not by how engaged they actually are with that county.
  supportedCountyMatchCount: number
}

/** Matches AchievementTier.forHomeMatchCount in UserData.swift. */
export function tierForHomeMatchCount(count: number): Tier | 'standard' {
  if (count >= 50) return 'gold'
  if (count >= 25) return 'silver'
  if (count >= 10) return 'bronze'
  return 'standard'
}

const teamKey = (countyId: string, sportCode: string) => `${countyId}:${sportCode}`

/**
 * Computes every signed-in-visible leaderboard entry in one pass, mirroring
 * LeaderboardView.swift's load(): overall + per-province match counts,
 * distinct ground counts, and county_home_match/county_away_match tier
 * tallies (bronze/silver/gold) for the "Most Bronze"/"Most Silver"/"Top
 * Gold" tabs. Only profiles with is_premium AND leaderboard_opt_in are
 * included -- premium alone isn't consent to publish someone's name/stats.
 */
export async function loadLeaderboardEntries(): Promise<LeaderboardEntry[]> {
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
  for (const m of matches ?? []) {
    const provs = new Set<string>()
    for (const teamId of [m.home_county_team_id, m.away_county_team_id]) {
      if (!teamId) continue
      const countyId = teamToCounty.get(teamId)
      const province = countyId ? countyToProvince.get(countyId) : undefined
      if (province) provs.add(province)
    }
    matchProvinces.set(m.id, provs)
  }

  const overallMatchCounts = new Map<string, number>()
  const provinceCounts = new Map<string, Map<string, number>>()
  for (const a of attendance ?? []) {
    overallMatchCounts.set(a.user_id, (overallMatchCounts.get(a.user_id) ?? 0) + 1)
    for (const province of matchProvinces.get(a.match_id) ?? []) {
      const byUser = provinceCounts.get(province) ?? new Map<string, number>()
      byUser.set(a.user_id, (byUser.get(a.user_id) ?? 0) + 1)
      provinceCounts.set(province, byUser)
    }
  }

  const groundIdsByUser = new Map<string, Set<string>>()
  for (const v of visits ?? []) {
    const set = groundIdsByUser.get(v.user_id) ?? new Set<string>()
    set.add(v.ground_id)
    groundIdsByUser.set(v.user_id, set)
  }

  // Home/road match counts per user, per (county, sport) -- same basis
  // county_home_match/county_away_match achievements are tiered on.
  const homeCounts = new Map<string, number>()
  const roadCounts = new Map<string, number>()
  for (const a of attendance ?? []) {
    const match = matchById.get(a.match_id)
    const groundId = match?.ground_id
    const groundCountyId = groundId ? groundCounty.get(groundId) : undefined
    if (!match || !groundCountyId) continue
    for (const teamId of [match.home_county_team_id, match.away_county_team_id]) {
      if (!teamId) continue
      const countyId = teamToCounty.get(teamId)
      const sportCode = teamSport.get(teamId)
      if (!countyId || !sportCode) continue
      const key = `${a.user_id}:${teamKey(countyId, sportCode)}`
      if (countyId === groundCountyId) {
        homeCounts.set(key, (homeCounts.get(key) ?? 0) + 1)
      } else {
        roadCounts.set(key, (roadCounts.get(key) ?? 0) + 1)
      }
    }
  }

  const defById = new Map((achievementDefs ?? []).map((d) => [d.id, d]))
  const tierCountsByUser = new Map<string, Record<Tier, number>>()
  for (const ua of userAchievements ?? []) {
    const def = defById.get(ua.achievement_id)
    if (!def || (def.rule_type !== 'county_home_match' && def.rule_type !== 'county_away_match')) continue
    const params = (def.rule_params ?? {}) as Record<string, unknown>
    const countyId = params.county_id as string | undefined
    const sportCode = params.sport_code as string | undefined
    if (!countyId || !sportCode) continue
    const key = `${ua.user_id}:${teamKey(countyId, sportCode)}`
    const count = def.rule_type === 'county_home_match' ? (homeCounts.get(key) ?? 0) : (roadCounts.get(key) ?? 0)
    const tier = tierForHomeMatchCount(count)
    if (tier === 'standard') continue
    const bucket = tierCountsByUser.get(ua.user_id) ?? { bronze: 0, silver: 0, gold: 0 }
    bucket[tier] += 1
    tierCountsByUser.set(ua.user_id, bucket)
  }

  const profileById = new Map((profiles ?? []).map((p) => [p.id, p]))
  const allIds = new Set([...overallMatchCounts.keys(), ...groundIdsByUser.keys()])

  // For each attended match, credit it to the attendee's supported-county
  // tally only if one of the two teams actually belongs to their county --
  // computed per-user (not globally per county) since every user has their
  // own supported county to check against.
  const supportedCountyMatchCounts = new Map<string, number>()
  for (const a of attendance ?? []) {
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
