import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import GroundCheckInPanel from '../components/GroundCheckInPanel'
import { useCountyPageBackground } from '../hooks/useCountyPageBackground'
import { formatMatchDate } from '../lib/format'

type Ground = { id: string; name: string; capacity: number | null; county_id: string; latitude: number; longitude: number }
type County = { id: string; name: string; primary_colour: string | null; secondary_colour: string | null }
type GameSeenHere = {
  attendanceId: string
  matchId: string
  competition: string | null
  playedAt: string
  homeName: string
  awayName: string
}

export default function GroundDetail() {
  const { id } = useParams<{ id: string }>()
  const { user } = useAuth()
  const [ground, setGround] = useState<Ground | null>(null)
  const [county, setCounty] = useState<County | null>(null)
  const [gamesSeenHere, setGamesSeenHere] = useState<GameSeenHere[]>([])
  const [gamesExpanded, setGamesExpanded] = useState(true)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!id) return
    let cancelled = false

    supabase
      .from('grounds')
      .select('id, name, capacity, county_id, latitude, longitude')
      .eq('id', id)
      .single()
      .then(async ({ data }) => {
        if (cancelled || !data) {
          if (!cancelled) setLoading(false)
          return
        }
        setGround(data)
        const { data: countyData } = await supabase
          .from('counties')
          .select('id, name, primary_colour, secondary_colour')
          .eq('id', data.county_id)
          .single()
        if (!cancelled) {
          setCounty(countyData)
          setLoading(false)
        }
      })

    return () => {
      cancelled = true
    }
  }, [id])

  useEffect(() => {
    if (!id || !user) {
      setGamesSeenHere([])
      return
    }
    let cancelled = false

    async function loadGamesSeenHere() {
      const { data: matchesHere } = await supabase
        .from('matches')
        .select('id, competition, played_at, home_county_team_id, away_county_team_id')
        .eq('ground_id', id!)
      if (cancelled || !matchesHere || matchesHere.length === 0) {
        if (!cancelled) setGamesSeenHere([])
        return
      }

      const matchIds = matchesHere.map((m) => m.id)
      const { data: attendance } = await supabase
        .from('user_match_attendance')
        .select('id, match_id')
        .eq('user_id', user!.id)
        .in('match_id', matchIds)
      if (cancelled || !attendance || attendance.length === 0) {
        if (!cancelled) setGamesSeenHere([])
        return
      }

      const matchById = new Map(matchesHere.map((m) => [m.id, m]))
      const teamIds = [
        ...new Set(matchesHere.flatMap((m) => [m.home_county_team_id, m.away_county_team_id].filter(Boolean))),
      ] as string[]
      const { data: teams } = teamIds.length
        ? await supabase.from('county_teams').select('id, county_id').in('id', teamIds)
        : { data: [] as { id: string; county_id: string }[] }
      const countyIds = [...new Set((teams ?? []).map((t) => t.county_id))]
      const { data: counties } = countyIds.length
        ? await supabase.from('counties').select('id, name').in('id', countyIds)
        : { data: [] as { id: string; name: string }[] }
      const countyNameById = new Map((counties ?? []).map((c) => [c.id, c.name]))
      const teamById = new Map((teams ?? []).map((t) => [t.id, t]))

      const rows = attendance
        .map((a): GameSeenHere | null => {
          const match = matchById.get(a.match_id)
          if (!match?.played_at) return null
          const home = match.home_county_team_id ? teamById.get(match.home_county_team_id) : null
          const away = match.away_county_team_id ? teamById.get(match.away_county_team_id) : null
          return {
            attendanceId: a.id,
            matchId: a.match_id,
            competition: match.competition,
            playedAt: match.played_at,
            homeName: home ? countyNameById.get(home.county_id) ?? 'TBC' : 'TBC',
            awayName: away ? countyNameById.get(away.county_id) ?? 'TBC' : 'TBC',
          }
        })
        .filter((r): r is GameSeenHere => r !== null)
        .sort((a, b) => b.playedAt.localeCompare(a.playedAt))

      if (!cancelled) setGamesSeenHere(rows)
    }

    loadGamesSeenHere()
    return () => {
      cancelled = true
    }
  }, [id, user])

  useCountyPageBackground(county?.primary_colour, county?.secondary_colour)

  if (loading) return <div className="page"><p className="muted">Loading…</p></div>
  if (!ground) return <div className="page"><p>Ground not found.</p></div>

  const mapUrl = `https://www.openstreetmap.org/?mlat=${ground.latitude}&mlon=${ground.longitude}#map=15/${ground.latitude}/${ground.longitude}`

  return (
    <div className="page">
      <div className="page-header">
        <h1>{ground.name}</h1>
        {county && (
          <p className="muted">
            <Link to={`/counties/${county.id}`}>{county.name}</Link>
          </p>
        )}
        {ground.capacity && <p className="muted small">Capacity: {ground.capacity.toLocaleString()}</p>}
        <a href={mapUrl} target="_blank" rel="noreferrer" className="link">
          View on map →
        </a>
      </div>

      {gamesSeenHere.length > 0 && (
        <div className="results-year">
          <button className="results-group-header" onClick={() => setGamesExpanded((v) => !v)}>
            <span>
              Games you've seen here <span className="muted small">({gamesSeenHere.length})</span>
            </span>
            <span>{gamesExpanded ? '▾' : '▸'}</span>
          </button>
          {gamesExpanded && (
            <ul className="history-list">
              {gamesSeenHere.map((g) => (
                <li key={g.attendanceId} className="history-list-item">
                  <Link to={`/matches/${g.matchId}`}>
                    <strong>
                      {g.homeName} v {g.awayName}
                    </strong>
                    <span className="muted small">
                      {g.competition ?? 'Gaelic Games'} · {formatMatchDate(g.playedAt)}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      <GroundCheckInPanel groundId={ground.id} />
    </div>
  )
}
