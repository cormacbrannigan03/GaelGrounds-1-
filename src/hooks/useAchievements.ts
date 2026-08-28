import { useCallback } from 'react'
import { supabase } from '../lib/supabaseClient'
import { loadAchievementState, qualifies, type AchievementDefinition } from '../lib/achievements'

/**
 * Reconciles achievement_definitions against the signed-in user's current
 * stats -- in both directions, across all rule_types (county_home_match,
 * county_away_match, county_grounds_complete, province_grounds_complete,
 * country_grounds_complete, ground_visit_count, match_attendance_count,
 * all_provinces_visited). Grants anything newly qualified, and revokes
 * anything previously granted that no longer qualifies (e.g. undoing the
 * one check-in that had put a county's home-game count over the "attend a
 * home game" threshold). Call this after every check-in AND every
 * undo/checkout -- only re-running it can catch something that stopped
 * qualifying.
 */
export function useAchievements(userId: string | undefined) {
  const evaluate = useCallback(async (): Promise<AchievementDefinition[]> => {
    if (!userId) return []

    const state = await loadAchievementState(userId)

    const newlyUnlocked: { achievement_id: string; user_id: string }[] = []
    const newDefs: AchievementDefinition[] = []
    const revokedRowIds: string[] = []

    for (const def of state.defs) {
      const earned = qualifies(def, state)
      if (earned === null) continue // unrecognised rule_type -- leave it alone, don't guess

      const existingRow = state.unlockedByDefId.get(def.id)
      if (earned && !existingRow) {
        newlyUnlocked.push({ achievement_id: def.id, user_id: userId })
        newDefs.push(def)
      } else if (!earned && existingRow) {
        revokedRowIds.push(existingRow.id)
      }
    }

    if (newlyUnlocked.length > 0) {
      await supabase.from('user_achievements').insert(newlyUnlocked)
    }
    if (revokedRowIds.length > 0) {
      await supabase.from('user_achievements').delete().in('id', revokedRowIds)
    }

    return newDefs
  }, [userId])

  return { evaluate }
}
