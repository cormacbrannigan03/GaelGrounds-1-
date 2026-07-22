import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import MatchCard, { type MatchCardData } from '../components/MatchCard'
import { isUpcoming } from '../lib/format'

type MatchRow = {
  id: string
  competition: string | null
  played_at: string
  home_score: string | null
  away_score: string | null
  ground_id: string | null
  home_county_team_id: string | null
  away_county_team_id: string | null
}

export default function Matches() {
  const [matches, setMatches] = useState<MatchCardData[]>([])
  const [filter, setFilter] = useState<'all' | 'upcoming' | 'results'>('all')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false

    async function load() {
      const { data: rows } = await supabase
        .from('matches')
        .select('id, competition, played_at, home_score, away_score, ground_id, home_county_team_id, away_county_team_id')
        .order('played_at', { ascending: false })
        .returns<MatchRow[]>()

      if (!rows || cancelled) {
        if (!cancelled) setLoading(false)
        return
      }

      const teamIds = [...new Set(rows.flatMap((m) => [m.home_county_team_id, m.away_county_team_id].filter(Boolean)))] as string[]
      const groundIds = [...new Set(rows.map((m) => m.ground_id).filter(Boolean))] as string[]

      const [{ data: teams }, { data: grounds }] = await Promise.all([
        teamIds.length ? supabase.from('county_teams').select('id, county_id').in('id', teamIds) : Promise.resolve({ data: [] as any[] }),
        groundIds.length ? supabase.from('grounds').select('id, name').in('id', groundIds) : Promise.resolve({ data: [] as any[] }),
      ])

      const countyIds = [...new Set((teams ?? []).map((t) => t.county_id))]
      const { data: counties } = countyIds.length
        ? await supabase.from('counties').select('id, name').in('id', countyIds)
        : { data: [] as any[] }

      const countyNameById = new Map((counties ?? []).map((c) => [c.id, c.name]))
      const teamById = new Map((teams ?? []).map((t) => [t.id, t]))
      const groundNameById = new Map((grounds ?? []).map((g) => [g.id, g.name]))

      const { data: att } = await supabase.from('user_match_attendance').select('match_id')
      const attendanceByMatch = new Map<string, number>()
      for (const a of att ?? []) attendanceByMatch.set(a.match_id, (attendanceByMatch.get(a.match_id) ?? 0) + 1)

      const cards: MatchCardData[] = rows.map((m) => {
        const home = m.home_county_team_id ? teamById.get(m.home_county_team_id) : null
        const away = m.away_county_team_id ? teamById.get(m.away_county_team_id) : null
        return {
          id: m.id,
          competition: m.competition,
          played_at: m.played_at,
          home_score: m.home_score,
          away_score: m.away_score,
          homeName: home ? countyNameById.get(home.county_id) ?? 'TBC' : 'TBC',
          awayName: away ? countyNameById.get(away.county_id) ?? 'TBC' : 'TBC',
          groundName: m.ground_id ? groundNameById.get(m.ground_id) ?? null : null,
          attendeeCount: attendanceByMatch.get(m.id) ?? 0,
        }
      })

      if (!cancelled) {
        setMatches(cards)
        setLoading(false)
      }
    }

    load()
    return () => {
      cancelled = true
    }
  }, [])

  const filtered = useMemo(() => {
    if (filter === 'all') return matches
    if (filter === 'upcoming') return matches.filter((m) => isUpcoming(m.played_at, Boolean(m.home_score && m.away_score)))
    return matches.filter((m) => Boolean(m.home_score && m.away_score))
  }, [matches, filter])

  return (
    <div className="page">
      <h1>Fixtures &amp; results</h1>
      <div className="filter-tabs">
        <button className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>
          All
        </button>
        <button className={filter === 'upcoming' ? 'active' : ''} onClick={() => setFilter('upcoming')}>
          Upcoming
        </button>
        <button className={filter === 'results' ? 'active' : ''} onClick={() => setFilter('results')}>
          Results
        </button>
      </div>

      {loading ? (
        <p className="muted">Loading matches…</p>
      ) : filtered.length === 0 ? (
        <p className="muted">No matches to show.</p>
      ) : (
        <div className="card-grid">
          {filtered.map((m) => (
            <MatchCard key={m.id} match={m} />
          ))}
        </div>
      )}
    </div>
  )
}
