import { useCallback } from 'react'
import { supabase } from '../lib/supabaseClient'

type RuleParams = { count?: number }

/**
 * Evaluates achievement_definitions.rule_type against the signed-in user's
 * current stats and inserts any newly-earned rows into user_achievements.
 * Safe to call after every check-in — insert is idempotent via the
 * (user_id, achievement_id) lookup below, and RLS still enforces user_id = auth.uid().
 */
export function useAchievements(userId: string | undefined) {
  const evaluate = useCallback(async (): Promise<string[]> => {
    if (!userId) return []

    const [{ data: defs }, { data: already }, { data: visits }, { data: attendance }] = await Promise.all([
      supabase.from('achievement_definitions').select('*'),
      supabase.from('user_achievements').select('achievement_id').eq('user_id', userId),
      supabase.from('user_visits').select('ground_id').eq('user_id', userId),
      supabase.from('user_match_attendance').select('id').eq('user_id', userId),
    ])

    if (!defs) return []

    const unlockedIds = new Set((already ?? []).map((a) => a.achievement_id))
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

    for (const def of defs) {
      if (unlockedIds.has(def.id)) continue
      const params = (def.rule_params ?? {}) as RuleParams
      let earned = false

      switch (def.rule_type) {
        case 'ground_visit_count':
          earned = groundCount >= (params.count ?? 1)
          break
        case 'match_attendance_count':
          earned = matchCount >= (params.count ?? 1)
          break
        case 'all_provinces_visited':
          earned = provinces.size >= 4
          break
      }

      if (earned) {
        newlyUnlocked.push({ achievement_id: def.id, user_id: userId })
        newTitles.push(def.title)
      }
    }

    if (newlyUnlocked.length > 0) {
      await supabase.from('user_achievements').insert(newlyUnlocked)
    }

    return newTitles
  }, [userId])

  return { evaluate }
}
