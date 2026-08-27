import { useEffect, useMemo, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import MatchCard, { type MatchCardData } from '../components/MatchCard'
import { SPORT_LABELS, SPORT_ICONS, isLive, isUpcoming } from '../lib/format'
import type { Enums } from '../lib/database.types'

type TeamRow = {
  id: string
  county_id: string
  sport_code: Enums<'sport_code'>
  founded_year: number | null
  current_manager: string | null
}
type MatchRow = {
  id: string
  competition: string | null
  played_at: string | null
  home_score: string | null
  away_score: string | null
  ground_id: string | null
  home_county_team_id: string | null
  away_county_team_id: string | null
}
type GroundRow = { id: string; name: string; capacity: number | null }

export default function TeamDetail() {
  const { teamId } = useParams<{ countyId: string; teamId: string }>()
  const [team, setTeam] = useState<TeamRow | null>(null)
  const [countyName, setCountyName] = useState('')
  const [matches, setMatches] = useState<MatchCardData[]>([])
  const [alternateGrounds, setAlternateGrounds] = useState<GroundRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!teamId) return
    let cancelled = false

    async function load() {
      const { data: teamRow } = await supabase
        .from('county_teams')
        .select('id, county_id, sport_code, founded_year, current_manager')
        .eq('id', teamId!)
        .single()
      if (cancelled || !teamRow) {
        if (!cancelled) setLoading(false)
        return
      }
      setTeam(teamRow)

      const { data: countyRow } = await supabase.from('counties').select('id, name').eq('id', teamRow.county_id).single()
      if (!cancelled) setCountyName(countyRow?.name ?? 'TBC')

      const { data: matchRows } = await supabase
        .from('matches')
        .select('id, competition, played_at, home_score, away_score, ground_id, home_county_team_id, away_county_team_id')
        .or(`home_county_team_id.eq.${teamId},away_county_team_id.eq.${teamId}`)
        .order('played_at', { ascending: false })
        .limit(40)

      if (cancelled || !matchRows) {
        if (!cancelled) setLoading(false)
        return
      }

      const teamIds = [
        ...new Set(matchRows.flatMap((m) => [m.home_county_team_id, m.away_county_team_id].filter(Boolean))),
      ] as string[]
      const groundIds = [...new Set(matchRows.map((m) => m.ground_id).filter(Boolean))] as string[]
      const [{ data: teams }, { data: grounds }] = await Promise.all([
        teamIds.length
          ? supabase.from('county_teams').select('id, county_id').in('id', teamIds)
          : Promise.resolve({ data: [] as { id: string; county_id: string }[] }),
        groundIds.length
          ? supabase.from('grounds').select('id, name, capacity').in('id', groundIds)
          : Promise.resolve({ data: [] as GroundRow[] }),
      ])
      const countyIds = [...new Set((teams ?? []).map((t) => t.county_id))]
      const { data: counties } = countyIds.length
        ? await supabase.from('counties').select('id, name, primary_colour, secondary_colour').in('id', countyIds)
        : { data: [] as { id: string; name: string; primary_colour: string | null; secondary_colour: string | null }[] }

      const countyById = new Map((counties ?? []).map((c) => [c.id, c]))
      const teamById = new Map((teams ?? []).map((t) => [t.id, t]))
      const groundById = new Map((grounds ?? []).map((g) => [g.id, g]))

      const cards: MatchCardData[] = matchRows.map((m) => {
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
          groundName: m.ground_id ? groundById.get(m.ground_id)?.name ?? null : null,
        }
      })

      if (!cancelled) {
        setMatches(cards)

        const upcomingGroundIds = [
          ...new Set(
            matchRows
              .filter((m: MatchRow) => {
                const hasScore = Boolean(m.home_score && m.away_score)
                return !hasScore && m.played_at && isUpcoming(m.played_at, hasScore)
              })
              .map((m: MatchRow) => m.ground_id)
              .filter(Boolean),
          ),
        ] as string[]
        setAlternateGrounds(upcomingGroundIds.map((gid) => groundById.get(gid)).filter((g): g is GroundRow => Boolean(g)))

        setLoading(false)
      }
    }

    load()
    return () => {
      cancelled = true
    }
  }, [teamId])

  const upcoming = useMemo(
    () =>
      matches.filter((m) => {
        const hasScore = Boolean(m.home_score && m.away_score)
        if (hasScore || !m.played_at) return false
        return isUpcoming(m.played_at, hasScore) || isLive(m.played_at, hasScore)
      }),
    [matches],
  )

  const results = useMemo(
    () =>
      matches.filter((m) => {
        const hasScore = Boolean(m.home_score && m.away_score)
        if (hasScore || !m.played_at) return true
        return !isUpcoming(m.played_at, hasScore) && !isLive(m.played_at, hasScore)
      }),
    [matches],
  )

  if (loading) return <div className="page"><p className="muted">Loading…</p></div>
  if (!team) return <div className="page"><p>Team not found.</p></div>

  return (
    <div className="page">
      <div className="page-header">
        <h1>{countyName}</h1>
        <p className="muted">
          {SPORT_ICONS[team.sport_code]} {SPORT_LABELS[team.sport_code]}
        </p>
        {team.founded_year && <p className="muted small">Founded {team.founded_year}</p>}
        {team.current_manager && <p className="muted small">Manager: {team.current_manager}</p>}
      </div>

      {upcoming.length > 0 && (
        <section>
          <h2>Upcoming fixtures</h2>
          <div className="card-grid">
            {upcoming.map((m) => (
              <MatchCard key={m.id} match={m} />
            ))}
          </div>
        </section>
      )}

      {alternateGrounds.length > 0 && (
        <section>
          <h2>Alternate Grounds</h2>
          <div className="card-grid">
            {alternateGrounds.map((g) => (
              <Link key={g.id} to={`/grounds/${g.id}`} className="card ground-card">
                <h3>📍 {g.name}</h3>
                {g.capacity && <p className="muted small">Capacity: {g.capacity.toLocaleString()}</p>}
              </Link>
            ))}
          </div>
        </section>
      )}

      <section>
        <h2>Recent results</h2>
        {results.length === 0 ? (
          <p className="muted">No results found.</p>
        ) : (
          <div className="card-grid">
            {results.map((m) => (
              <MatchCard key={m.id} match={m} />
            ))}
          </div>
        )}
      </section>
    </div>
  )
}
