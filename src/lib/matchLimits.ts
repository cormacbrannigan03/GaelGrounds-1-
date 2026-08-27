import { supabase } from './supabaseClient'

// Matches MatchService.swift's free-tier constants -- the real enforcement
// is server-side (RLS "free tier check-in limits"/"free tier personal match
// limits" policies + the total_match_count() Postgres function), these are
// just the client-side mirror so the UI can show an upgrade prompt
// proactively instead of a bare failed-insert.
export const FREE_MATCH_LIMIT = 10
export const FREE_HISTORY_CUTOFF = '2019-01-01T00:00:00Z'

export function isDateAllowedForFreeTier(iso: string | null | undefined) {
  if (!iso) return true
  return iso >= FREE_HISTORY_CUTOFF
}

export async function fetchTotalMatchCount(userId: string): Promise<number> {
  const { data, error } = await supabase.rpc('total_match_count', { p_user_id: userId })
  if (error || typeof data !== 'number') return FREE_MATCH_LIMIT
  return data
}

export async function canLogAnotherMatch(userId: string, isPremium: boolean): Promise<boolean> {
  if (isPremium) return true
  const count = await fetchTotalMatchCount(userId)
  return count < FREE_MATCH_LIMIT
}
