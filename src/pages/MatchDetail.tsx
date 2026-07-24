import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import CheckInPanel from '../components/CheckInPanel'
import { formatMatchDate, isLive } from '../lib/format'

type Match = {
  id: string
  competition: string | null
  played_at: string
  home_score: string | null
  away_score: string | null
  ground_id: string | null
  home_county_team_id: string | null
  away_county_team_id: string | null
}

export default function MatchDetail() {
  const { id } = useParams<{ id: string }>()
  const [match, setMatch] = useState<Match | null>(null)
  const [homeName, setHomeName] = useState('TBC')
  const [awayName, setAwayName] = useState('TBC')
  const [ground, setGround] = useState<{ id: string; name: string } | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!id) return
    let cancelled = false

    async function load() {
      const { data: m } = await supabase
        .from('matches')
        .select('id, competition, played_at, home_score, away_score, ground_id, home_county_team_id, away_county_team_id')
        .eq('id', id!)
        .single()

      if (cancelled || !m) {
        if (!cancelled) setLoading(false)
        return
      }
      setMatch(m)

      const teamIds = [m.home_county_team_id, m.away_county_team_id].filter(Boolean) as string[]
      const { data: teams } = teamIds.length
        ? await supabase.from('county_teams').select('id, county_id').in('id', teamIds)
        : { data: [] as any[] }
      const countyIds = [...new Set((teams ?? []).map((t) => t.county_id))]
      const { data: counties } = countyIds.length
        ? await supabase.from('counties').select('id, name').in('id', countyIds)
        : { data: [] as any[] }
      const countyNameById = new Map((counties ?? []).map((c) => [c.id, c.name]))
      const teamById = new Map((teams ?? []).map((t) => [t.id, t]))

      if (m.home_county_team_id) {
        const home = teamById.get(m.home_county_team_id)
        setHomeName(home ? countyNameById.get(home.county_id) ?? 'TBC' : 'TBC')
      }
      if (m.away_county_team_id) {
        const away = teamById.get(m.away_county_team_id)
        setAwayName(away ? countyNameById.get(away.county_id) ?? 'TBC' : 'TBC')
      }

      if (m.ground_id) {
        const { data: g } = await supabase.from('grounds').select('id, name').eq('id', m.ground_id).single()
        if (!cancelled) setGround(g)
      }

      if (!cancelled) setLoading(false)
    }

    load()
    return () => {
      cancelled = true
    }
  }, [id])

  if (loading) return <div className="page"><p className="muted">Loading…</p></div>
  if (!match) return <div className="page"><p>Match not found.</p></div>

  const hasScore = Boolean(match.home_score && match.away_score)
  const live = isLive(match.played_at, hasScore)

  return (
    <div className="page">
      <div className="page-header">
        <span className="competition">{match.competition ?? 'Gaelic Games'}</span>
        {live && <span className="badge badge-live">● LIVE</span>}
        <h1 className="match-title">
          {homeName} <span className="vs">v</span> {awayName}
        </h1>
        {hasScore && (
          <p className="score-line">
            {match.home_score} – {match.away_score}
          </p>
        )}
        <p className="muted">{formatMatchDate(match.played_at)}</p>
        {ground && (
          <p className="muted">
            📍 <Link to={`/grounds/${ground.id}`}>{ground.name}</Link>
          </p>
        )}
      </div>

      <CheckInPanel matchId={match.id} isPast={hasScore || (!live && new Date(match.played_at).getTime() < Date.now())} />
    </div>
  )
}
