import type { Enums } from './database.types'

export type CountyColours = { primary: string; secondary: string }

/** Converts a "#RRGGBB" hex string to an "r, g, b" triplet for use inside CSS rgba(). */
export function hexToRgbTriplet(hex: string): string {
  const clean = hex.replace('#', '')
  const r = parseInt(clean.slice(0, 2), 16)
  const g = parseInt(clean.slice(2, 4), 16)
  const b = parseInt(clean.slice(4, 6), 16)
  return `${r}, ${g}, ${b}`
}

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

/** GAA "goals-points" score string (e.g. "1-14") -> total points, goal = 3. */
function parseGaaScore(score: string): number {
  const parts = score.split('-')
  if (parts.length !== 2) return 0
  const goals = parseInt(parts[0].trim(), 10)
  const points = parseInt(parts[1].trim(), 10)
  if (Number.isNaN(goals) || Number.isNaN(points)) return 0
  return goals * 3 + points
}

/** Matches MatchSummary.swift's isFinal -- competition/round text mentions "final". */
export function isFinalMatch(competition: string | null, round: string | null) {
  return `${competition ?? ''} ${round ?? ''}`.toLowerCase().includes('final')
}

/** The winning team's name, or null if there's no score yet or it's a draw. */
export function winnerName(
  homeScore: string | null,
  awayScore: string | null,
  homeName: string,
  awayName: string,
): string | null {
  if (!homeScore || !awayScore) return null
  const home = parseGaaScore(homeScore)
  const away = parseGaaScore(awayScore)
  if (home > away) return homeName
  if (away > home) return awayName
  return null
}
