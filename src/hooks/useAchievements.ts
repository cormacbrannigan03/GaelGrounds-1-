import { useCallback } from 'react'
import { supabase } from '../lib/supabaseClient'

type RuleParams = { count?: number }

/**
 * Reconciles achievement_definitions.rule_type against the signed-in user's
 * current stats -- in both directions. Grants anything newly qualified, and
 * just as importantly, revokes anything previously granted that no longer
 * qualifies (e.g. undoing the one check-in that had put a match count over
 * a threshold). Call this after every check-in AND every undo/checkout --
 * unlike a grant-only evaluator, this one has to run on both, since only
 * re-running it can catch something that stopped qualifying.
 */
export function useAchievements(userId: string | undefined) {
  const evaluate = useCallback(async (): Promise<string[]> => {
    if (!userId) return []

    const [{ data: defs }, { data: already }, { data: visits }, { data: attendance }] = await Promise.all([
      supabase.from('achievement_definitions').select('*'),
      supabase.from('user_achievements').select('id, achievement_id').eq('user_id', userId),
      supabase.from('user_visits').select('ground_id').eq('user_id', userId),
      supabase.from('user_match_attendance').select('id').eq('user_id', userId),
    ])

    if (!defs) return []

    const unlockedRowByAchievementId = new Map((already ?? []).map((a) => [a.achievement_id, a.id]))
    const groundIds = [...new Set((visits ?? []).map((v) => v.ground_id))]
    const groundCount = groundIds.length
    const matchCount = (attendance ?? []).length

    const provinces = new Set<string>()
    if (groundIds.length > 0) {
      const { data: groundsData } = await supabase.from('grounds').select('county_id').in('id', groundIds)
      const countyIds = [...new Set((groundsData ?? []).map((g) => g.county_id))]
      if (countyIds.length > 0) {
        const { data: countiesData } = await supabase.from('counties').select('province').in('id', countyIds)
        for (const c of countiesData ?? []) provinces.add(c.province)
      }
    }

    const newlyUnlocked: { achievement_id: string; user_id: string }[] = []
    const newTitles: string[] = []
    const revokedRowIds: string[] = []

    for (const def of defs) {
      const params = (def.rule_params ?? {}) as RuleParams
      let qualifies = false

      switch (def.rule_type) {
        case 'ground_visit_count':
          qualifies = groundCount >= (params.count ?? 1)
          break
        case 'match_attendance_count':
          qualifies = matchCount >= (params.count ?? 1)
          break
        case 'all_provinces_visited':
          qualifies = provinces.size >= 4
          break
        default:
          // A rule type this hook doesn't know how to evaluate -- leave
          // whatever's already there alone rather than guessing wrong and
          // revoking something it shouldn't.
          continue
      }

      const existingRowId = unlockedRowByAchievementId.get(def.id)
      if (qualifies && !existingRowId) {
        newlyUnlocked.push({ achievement_id: def.id, user_id: userId })
        newTitles.push(def.title)
      } else if (!qualifies && existingRowId) {
        revokedRowIds.push(existingRowId)
      }
    }

    if (newlyUnlocked.length > 0) {
      await supabase.from('user_achievements').insert(newlyUnlocked)
    }
    if (revokedRowIds.length > 0) {
      await supabase.from('user_achievements').delete().in('id', revokedRowIds)
    }

    return newTitles
  }, [userId])

  return { evaluate }
}
