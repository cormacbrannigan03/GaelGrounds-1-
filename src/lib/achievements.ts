import { supabase } from './supabaseClient'

export const MAX_PINNED_ACHIEVEMENTS = 4

export type AchievementDefinition = {
  id: string
  code: string
  title: string
  description: string
  icon: string | null
  rule_type: string
  rule_params: Record<string, unknown> | null
}

export type UnlockedRow = { id: string; achievement_id: string; unlocked_at: string; pinned: boolean }

export type AchievementState = {
  defs: AchievementDefinition[]
  unlockedByDefId: Map<string, UnlockedRow>
  groundCount: number
  matchCount: number
  provinceCount: number
  /** `${countyId}:${sportCode}` -> verified home-game count */
  homeCounts: Map<string, number>
  /** `${countyId}:${sportCode}` -> verified away/road-game count */
  roadCounts: Map<string, number>
  groundsByCounty: Map<string, string[]>
  groundsByProvince: Map<string, string[]>
  visitedGroundIds: Set<string>
  allGroundIds: Set<string>
}

const homeKey = (countyId: string, sportCode: string) => `${countyId}:${sportCode}`

/**
 * Loads everything needed to grant/revoke achievements and to render the
 * Achievements page, in one place -- mirrors the joins in
 * AchievementsService.swift's evaluate()/homeMatchCounts()/roadMatchCounts()
 * so web, iOS and Android agree on what counts as "earned."
 */
export async function loadAchievementState(userId: string): Promise<AchievementState> {
  const [{ data: defs }, { data: unlocked }, { data: visits }, { data: attendance }, { data: allGrounds }, { data: allCounties }] =
    await Promise.all([
      supabase.from('achievement_definitions').select('id, code, title, description, icon, rule_type, rule_params'),
      supabase.from('user_achievements').select('id, achievement_id, unlocked_at, pinned').eq('user_id', userId),
      supabase.from('user_visits').select('ground_id').eq('user_id', userId),
      supabase.from('user_match_attendance').select('id, match_id').eq('user_id', userId),
      supabase.from('grounds').select('id, county_id'),
      supabase.from('counties').select('id, province'),
    ])

  const unlockedByDefId = new Map((unlocked ?? []).map((u) => [u.achievement_id, u as UnlockedRow]))
  const visitedGroundIds = new Set((visits ?? []).map((v) => v.ground_id))
  const groundCount = visitedGroundIds.size
  const matchCount = (attendance ?? []).length

  const provinceByCountyId = new Map((allCounties ?? []).map((c) => [c.id, c.province]))
  const groundById = new Map((allGrounds ?? []).map((g) => [g.id, g]))

  const provinces = new Set<string>()
  for (const groundId of visitedGroundIds) {
    const ground = groundById.get(groundId)
    const province = ground ? provinceByCountyId.get(ground.county_id) : undefined
    if (province) provinces.add(province)
  }

  const groundsByCounty = new Map<string, string[]>()
  const groundsByProvince = new Map<string, string[]>()
  for (const g of allGrounds ?? []) {
    groundsByCounty.set(g.county_id, [...(groundsByCounty.get(g.county_id) ?? []), g.id])
    const province = provinceByCountyId.get(g.county_id)
    if (province) groundsByProvince.set(province, [...(groundsByProvince.get(province) ?? []), g.id])
  }

  const homeCounts = new Map<string, number>()
  const roadCounts = new Map<string, number>()
  const matchIds = [...new Set((attendance ?? []).map((a) => a.match_id))]
  if (matchIds.length > 0) {
    const { data: matches } = await supabase
      .from('matches')
      .select('id, home_county_team_id, away_county_team_id, ground_id')
      .in('id', matchIds)

    const teamIds = [
      ...new Set((matches ?? []).flatMap((m) => [m.home_county_team_id, m.away_county_team_id].filter(Boolean))),
    ] as string[]
    const groundIds = [...new Set((matches ?? []).map((m) => m.ground_id).filter(Boolean))] as string[]

    const [{ data: teams }, { data: matchGrounds }] = await Promise.all([
      teamIds.length
        ? supabase.from('county_teams').select('id, county_id, sport_code').in('id', teamIds)
        : Promise.resolve({ data: [] as { id: string; county_id: string; sport_code: string }[] }),
      groundIds.length
        ? supabase.from('grounds').select('id, county_id').in('id', groundIds)
        : Promise.resolve({ data: [] as { id: string; county_id: string }[] }),
    ])

    const teamById = new Map((teams ?? []).map((t) => [t.id, t]))
    const matchGroundById = new Map((matchGrounds ?? []).map((g) => [g.id, g]))

    for (const m of matches ?? []) {
      const ground = m.ground_id ? matchGroundById.get(m.ground_id) : undefined
      if (!ground) continue

      // Home: only when the fixture's designated home team's own county
      // matches the venue's county -- excludes neutral championship venues.
      if (m.home_county_team_id) {
        const team = teamById.get(m.home_county_team_id)
        if (team && team.county_id === ground.county_id) {
          const key = homeKey(team.county_id, team.sport_code)
          homeCounts.set(key, (homeCounts.get(key) ?? 0) + 1)
        }
      }

      // Road: any participating team (either side of the fixture) whose own
      // county isn't the venue's county -- includes neutral venues as away
      // games for both sides.
      for (const teamId of [m.home_county_team_id, m.away_county_team_id]) {
        if (!teamId) continue
        const team = teamById.get(teamId)
        if (team && team.county_id !== ground.county_id) {
          const key = homeKey(team.county_id, team.sport_code)
          roadCounts.set(key, (roadCounts.get(key) ?? 0) + 1)
        }
      }
    }
  }

  return {
    defs: (defs ?? []) as AchievementDefinition[],
    unlockedByDefId,
    groundCount,
    matchCount,
    provinceCount: provinces.size,
    homeCounts,
    roadCounts,
    groundsByCounty,
    groundsByProvince,
    visitedGroundIds,
    allGroundIds: new Set((allGrounds ?? []).map((g) => g.id)),
  }
}

/**
 * Whether `def` is currently earned given `state`. Returns `null` -- not
 * false -- for a rule_type this function doesn't recognise, so a future
 * achievement type added server-side never gets silently revoked by a web
 * client that just doesn't understand it yet.
 */
export function qualifies(def: AchievementDefinition, state: AchievementState): boolean | null {
  const params = (def.rule_params ?? {}) as Record<string, unknown>

  switch (def.rule_type) {
    case 'ground_visit_count':
      return state.groundCount >= (Number(params.count) || 1)
    case 'match_attendance_count':
      return state.matchCount >= (Number(params.count) || 1)
    case 'all_provinces_visited':
      return state.provinceCount >= 4
    case 'county_home_match': {
      const countyId = params.county_id as string | undefined
      const sportCode = params.sport_code as string | undefined
      if (!countyId || !sportCode) return false
      return (state.homeCounts.get(homeKey(countyId, sportCode)) ?? 0) >= 1
    }
    case 'county_away_match': {
      const countyId = params.county_id as string | undefined
      const sportCode = params.sport_code as string | undefined
      if (!countyId || !sportCode) return false
      return (state.roadCounts.get(homeKey(countyId, sportCode)) ?? 0) >= 1
    }
    case 'county_grounds_complete': {
      const countyId = params.county_id as string | undefined
      const countyGrounds = countyId ? state.groundsByCounty.get(countyId) : undefined
      if (!countyGrounds || countyGrounds.length === 0) return false
      return countyGrounds.every((id) => state.visitedGroundIds.has(id))
    }
    case 'province_grounds_complete': {
      const province = params.province as string | undefined
      const provinceGrounds = province ? state.groundsByProvince.get(province) : undefined
      if (!provinceGrounds || provinceGrounds.length === 0) return false
      return provinceGrounds.every((id) => state.visitedGroundIds.has(id))
    }
    case 'country_grounds_complete':
      return state.allGroundIds.size > 0 && [...state.allGroundIds].every((id) => state.visitedGroundIds.has(id))
    default:
      return null
  }
}

export function countyIdOf(def: AchievementDefinition): string | null {
  return (def.rule_params?.county_id as string | undefined) ?? null
}

export function provinceOf(def: AchievementDefinition): string | null {
  return (def.rule_params?.province as string | undefined) ?? null
}
