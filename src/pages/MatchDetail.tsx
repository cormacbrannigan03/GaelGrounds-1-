import { useEffect, useMemo, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import CheckInPanel from '../components/CheckInPanel'
import ConfettiOverlay from '../components/ConfettiOverlay'
import ReportMatchIssue from '../components/ReportMatchIssue'
import { useCountyPageBackground } from '../hooks/useCountyPageBackground'
import { formatMatchDate, isFinalMatch, isLive, winnerName } from '../lib/format'

type Match = {
  id: string
  competition: string | null
  round: string | null
  played_at: string | null
  home_score: string | null
  away_score: string | null
  ground_id: string | null
  home_county_team_id: string | null
  away_county_team_id: string | null
}

type CountyRef = { name: string; primary_colour: string | null; secondary_colour: string | null }

export default function MatchDetail() {
  const { id } = useParams<{ id: string }>()
  const [match, setMatch] = useState<Match | null>(null)
  const [homeCounty, setHomeCounty] = useState<CountyRef>({ name: 'TBC', primary_colour: null, secondary_colour: null })
  const [awayCounty, setAwayCounty] = useState<CountyRef>({ name: 'TBC', primary_colour: null, secondary_colour: null })
  const [ground, setGround] = useState<{ id: string; name: string } | null>(null)
  const [loading, setLoading] = useState(true)
  const [showConfetti, setShowConfetti] = useState(false)

  useEffect(() => {
    if (!id) return
    let cancelled = false
    // Reset so confetti from a previous match's Final doesn't carry over
    // when navigating client-side from one match detail page to another.
    setShowConfetti(false)

    async function load() {
      const { data: m } = await supabase
        .from('matches')
        .select(
          'id, competition, round, played_at, home_score, away_score, ground_id, home_county_team_id, away_county_team_id',
        )
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
        ? await supabase.from('counties').select('id, name, primary_colour, secondary_colour').in('id', countyIds)
        : { data: [] as any[] }
      const countyById = new Map((counties ?? []).map((c) => [c.id, c]))
      const teamById = new Map((teams ?? []).map((t) => [t.id, t]))

      if (m.home_county_team_id) {
        const home = teamById.get(m.home_county_team_id)
        const county = home ? countyById.get(home.county_id) : null
        if (county) setHomeCounty({ name: county.name, primary_colour: county.primary_colour, secondary_colour: county.secondary_colour })
      }
      if (m.away_county_team_id) {
        const away = teamById.get(m.away_county_team_id)
        const county = away ? countyById.get(away.county_id) : null
        if (county) setAwayCounty({ name: county.name, primary_colour: county.primary_colour, secondary_colour: county.secondary_colour })
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

  const hasScore = Boolean(match?.home_score && match?.away_score)
  const winner = match ? winnerName(match.home_score, match.away_score, homeCounty.name, awayCounty.name) : null
  const isFinal = match ? isFinalMatch(match.competition, match.round) : false
  const winnerCounty = winner === homeCounty.name ? homeCounty : winner === awayCounty.name ? awayCounty : null

  // Confetti fires once, the first time a Final's result loads with a
  // winner -- matches MatchDetailView.swift firing confettiWinner from
  // .onAppear/load rather than re-triggering on every render.
  useEffect(() => {
    if (!loading && isFinal && winner) {
      const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
      if (!reduceMotion) setShowConfetti(true)
    }
  }, [loading, isFinal, winner])

  useCountyPageBackground(winnerCounty?.primary_colour, winnerCounty?.secondary_colour)

  const confettiColors = useMemo<[string, string]>(() => {
    return [winnerCounty?.primary_colour ?? '#0b3d2e', winnerCounty?.secondary_colour ?? '#d9a441']
  }, [winnerCounty])

  if (loading) return <div className="page"><p className="muted">Loading…</p></div>
  if (!match) return <div className="page"><p>Match not found.</p></div>

  const live = match.played_at ? isLive(match.played_at, hasScore) : false
  const isPast = hasScore || (match.played_at ? !live && new Date(match.played_at).getTime() < Date.now() : false)

  return (
    <div className="page">
      {showConfetti && <ConfettiOverlay colors={confettiColors} />}

      <div className="page-header">
        <span className="competition">{match.competition ?? 'Gaelic Games'}</span>
        {live && <span className="badge badge-live">● LIVE</span>}
        <h1 className="match-title">
          {homeCounty.name} <span className="vs">v</span> {awayCounty.name}
        </h1>
        {hasScore && (
          <p className="score-line">
            {match.home_score} – {match.away_score}
          </p>
        )}
        {match.played_at && <p className="muted">{formatMatchDate(match.played_at)}</p>}
        {ground && (
          <p className="muted">
            📍 <Link to={`/grounds/${ground.id}`}>{ground.name}</Link>
          </p>
        )}
        <ReportMatchIssue matchId={match.id} />
      </div>

      <CheckInPanel matchId={match.id} isPast={isPast} matchPlayedAt={match.played_at} />
    </div>
  )
}
