import type { Enums } from './database.types'

export const SPORT_LABELS: Record<Enums<'sport_code'>, string> = {
  gaelic_football: 'Gaelic Football',
  hurling: 'Hurling',
  camogie: 'Camogie',
  ladies_football: "Ladies' Football",
}

export const SPORT_ICONS: Record<Enums<'sport_code'>, string> = {
  gaelic_football: '🏐',
  hurling: '🏑',
  camogie: '🏑',
  ladies_football: '🏐',
}

export function formatMatchDate(iso: string) {
  const d = new Date(iso)
  return d.toLocaleString('en-IE', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function formatShortDate(iso: string) {
  return new Date(iso).toLocaleDateString('en-IE', { day: 'numeric', month: 'short', year: 'numeric' })
}

/** A match counts as "live" if it kicked off in the last ~2.5 hours and hasn't been scored yet. */
export function isLive(playedAt: string, hasScore: boolean) {
  if (hasScore) return false
  const start = new Date(playedAt).getTime()
  const now = Date.now()
  const MATCH_WINDOW_MS = 2.5 * 60 * 60 * 1000
  return now >= start && now - start <= MATCH_WINDOW_MS
}

export function isUpcoming(playedAt: string, hasScore: boolean) {
  if (hasScore) return false
  return new Date(playedAt).getTime() > Date.now()
}
