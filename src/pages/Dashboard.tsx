import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import MatchCard, { type MatchCardData } from '../components/MatchCard'

export default function Dashboard() {
  const { user } = useAuth()
  const [liveAndUpcoming, setLiveAndUpcoming] = useState<MatchCardData[]>([])
  const [stats, setStats] = useState({ grounds: 0, matches: 0, achievements: 0 })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false

    async function load() {
      const nowIso = new Date().toISOString()
      const twoHoursAgo = new Date(Date.now() - 2.5 * 60 * 60 * 1000).toISOString()

      const { data: matchRows } = await supabase
        .from('matches')
        .select('id, competition, played_at, home_score, away_score, ground_id, home_county_team_id, away_county_team_id')
        .gte('played_at', twoHoursAgo)
        .order('played_at', { ascending: true })
        .limit(6)
      const matches = (matchRows ?? []).filter(
        (m): m is typeof m & { played_at: string } => m.played_at !== null,
      )

      const teamIds = [
        ...new Set((matches ?? []).flatMap((m) => [m.home_county_team_id, m.away_county_team_id].filter(Boolean))),
      ] as string[]
      const groundIds = [...new Set((matches ?? []).map((m) => m.ground_id).filter(Boolean))] as string[]

      const [{ data: teams }, { data: grounds }] = await Promise.all([
        teamIds.length
          ? supabase.from('county_teams').select('id, county_id, sport_code').in('id', teamIds)
          : Promise.resolve({ data: [] as any[] }),
        groundIds.length
          ? supabase.from('grounds').select('id, name').in('id', groundIds)
          : Promise.resolve({ data: [] as any[] }),
      ])

      const countyIds = [...new Set((teams ?? []).map((t) => t.county_id))]
      const { data: counties } = countyIds.length
        ? await supabase.from('counties').select('id, name, primary_colour, secondary_colour').in('id', countyIds)
        : { data: [] as any[] }

      const countyById = new Map((counties ?? []).map((c) => [c.id, c]))
      const teamById = new Map((teams ?? []).map((t) => [t.id, t]))
      const groundNameById = new Map((grounds ?? []).map((g) => [g.id, g.name]))

      let attendanceByMatch = new Map<string, number>()
      if (matches && matches.length > 0) {
        const { data: att } = await supabase
          .from('user_match_attendance')
          .select('match_id')
          .in(
            'match_id',
            matches.map((m) => m.id),
          )
        for (const a of att ?? []) attendanceByMatch.set(a.match_id, (attendanceByMatch.get(a.match_id) ?? 0) + 1)
      }

      const cards: MatchCardData[] = (matches ?? []).map((m) => {
        const home = m.home_county_team_id ? teamById.get(m.home_county_team_id) : null
        const away = m.away_county_team_id ? teamById.get(m.away_county_team_id) : null
        const homeCounty = home ? countyById.get(home.county_id) : null
        const awayCounty = away ? countyById.get(away.county_id) : null
        return {
          id: m.id,
          competition: m.competition,
          played_at: m.played_at,
          home_score: m.home_score,
          away_score: m.away_score,
          homeName: homeCounty?.name ?? 'TBC',
          awayName: awayCounty?.name ?? 'TBC',
          homeColours:
            homeCounty?.primary_colour && homeCounty?.secondary_colour
              ? { primary: homeCounty.primary_colour, secondary: homeCounty.secondary_colour }
              : null,
          awayColours:
            awayCounty?.primary_colour && awayCounty?.secondary_colour
              ? { primary: awayCounty.primary_colour, secondary: awayCounty.secondary_colour }
              : null,
          groundName: m.ground_id ? groundNameById.get(m.ground_id) ?? null : null,
          attendeeCount: attendanceByMatch.get(m.id) ?? 0,
        }
      })

      if (!cancelled) setLiveAndUpcoming(cards)

      if (user) {
        const [{ count: groundsCount }, { count: matchesCount }, { count: achievementsCount }] = await Promise.all([
          supabase.from('user_visits').select('id', { count: 'exact', head: true }).eq('user_id', user.id),
          supabase.from('user_match_attendance').select('id', { count: 'exact', head: true }).eq('user_id', user.id),
          supabase.from('user_achievements').select('id', { count: 'exact', head: true }).eq('user_id', user.id),
        ])
        if (!cancelled) {
          setStats({
            grounds: groundsCount ?? 0,
            matches: matchesCount ?? 0,
            achievements: achievementsCount ?? 0,
          })
        }
      }

      if (!cancelled) setLoading(false)
    }

    load()
    return () => {
      cancelled = true
    }
  }, [user])

  return (
    <div className="page">
      <section className="hero">
        <h1>Every ground. Every code. Every county.</h1>
        <p className="muted">
          Check in at Gaelic football, hurling, camogie and ladies' football matches in real time, and build your
          own record of the grounds you've stood in across all 32 counties.
        </p>
        {!user && (
          <Link to="/auth" className="btn btn-primary btn-lg">
            Get started
          </Link>
        )}
      </section>

      {user && (
        <section className="stats-row">
          <Link to="/profile" className="stat-tile">
            <span className="stat-value">{stats.grounds}</span>
            <span className="stat-label">Grounds visited</span>
          </Link>
          <Link to="/profile" className="stat-tile">
            <span className="stat-value">{stats.matches}</span>
            <span className="stat-label">Matches attended</span>
          </Link>
          <Link to="/profile" className="stat-tile">
            <span className="stat-value">{stats.achievements}</span>
            <span className="stat-label">Achievements</span>
          </Link>
        </section>
      )}

      <section>
        <div className="section-header">
          <h2>Live &amp; upcoming</h2>
          <Link to="/matches" className="link">
            See all fixtures →
          </Link>
        </div>
        {loading ? (
          <p className="muted">Loading fixtures…</p>
        ) : liveAndUpcoming.length === 0 ? (
          <p className="muted">No live or upcoming matches right now — check back soon.</p>
        ) : (
          <div className="card-grid">
            {liveAndUpcoming.map((m) => (
              <MatchCard key={m.id} match={m} />
            ))}
          </div>
        )}
      </section>
    </div>
  )
}
