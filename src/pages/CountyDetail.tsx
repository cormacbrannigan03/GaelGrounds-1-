import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import type { Enums } from '../lib/database.types'
import { SPORT_LABELS, SPORT_ICONS } from '../lib/format'
import { useCountyPageBackground } from '../hooks/useCountyPageBackground'

type County = {
  id: string
  name: string
  province: Enums<'province'>
  primary_colour: string | null
  secondary_colour: string | null
  nickname: string | null
}
type TeamRow = { id: string; sport_code: Enums<'sport_code'>; founded_year: number | null; current_manager: string | null }
type GroundRow = { id: string; name: string; capacity: number | null }
type HonourRow = {
  id: string
  competition_name: string
  year: number
  honour_type: Enums<'honour_type'>
  county_team_id: string | null
}

export default function CountyDetail() {
  const { id } = useParams<{ id: string }>()
  const [county, setCounty] = useState<County | null>(null)
  const [teams, setTeams] = useState<TeamRow[]>([])
  const [grounds, setGrounds] = useState<GroundRow[]>([])
  const [honours, setHonours] = useState<HonourRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!id) return
    let cancelled = false

    async function load() {
      const [{ data: countyData }, { data: teamData }, { data: groundData }] = await Promise.all([
        supabase.from('counties').select('id, name, province, primary_colour, secondary_colour, nickname').eq('id', id!).single(),
        supabase
          .from('county_teams')
          .select('id, sport_code, founded_year, current_manager')
          .eq('county_id', id!)
          .in('sport_code', ['gaelic_football', 'hurling']),
        supabase.from('grounds').select('id, name, capacity').eq('county_id', id!),
      ])

      if (cancelled) return
      setCounty(countyData)
      setTeams(teamData ?? [])
      setGrounds(groundData ?? [])

      const teamIds = (teamData ?? []).map((t) => t.id)
      if (teamIds.length > 0) {
        const { data: honourData } = await supabase
          .from('honours')
          .select('id, competition_name, year, honour_type, county_team_id')
          .in('county_team_id', teamIds)
          .order('year', { ascending: false })
        if (!cancelled) setHonours(honourData ?? [])
      }

      if (!cancelled) setLoading(false)
    }

    load()
    return () => {
      cancelled = true
    }
  }, [id])

  useCountyPageBackground(county?.primary_colour, county?.secondary_colour)

  if (loading) return <div className="page"><p className="muted">Loading…</p></div>
  if (!county) return <div className="page"><p>County not found.</p></div>

  return (
    <div className="page">
      <div className="page-header" style={{ borderColor: county.primary_colour ?? undefined }}>
        <h1>{county.name}</h1>
        <p className="muted">{county.province}</p>
        {county.nickname && <p className="county-nickname">{county.nickname}</p>}
      </div>

      <section>
        <h2>Intercounty teams</h2>
        <div className="card-grid">
          {teams.map((t) => (
            <Link key={t.id} to={`/counties/${id}/teams/${t.id}`} className="card">
              <h3>
                {SPORT_ICONS[t.sport_code]} {SPORT_LABELS[t.sport_code]}
              </h3>
              {t.founded_year && <p className="muted small">Founded {t.founded_year}</p>}
              {t.current_manager && <p className="muted small">Manager: {t.current_manager}</p>}
            </Link>
          ))}
        </div>
      </section>

      <section>
        <h2>Home grounds</h2>
        <div className="card-grid">
          {grounds.map((g) => (
            <Link key={g.id} to={`/grounds/${g.id}`} className="card ground-card">
              <h3>{g.name}</h3>
              {g.capacity && <p className="muted small">Capacity: {g.capacity.toLocaleString()}</p>}
            </Link>
          ))}
        </div>
      </section>

      {honours.length > 0 && (
        <section>
          <h2>Roll of honour</h2>
          {teams.map((team) => {
            const teamHonours = honours.filter((h) => h.county_team_id === team.id)
            if (teamHonours.length === 0) return null

            const byCompetition = new Map<string, number[]>()
            for (const h of teamHonours) {
              const years = byCompetition.get(h.competition_name) ?? []
              years.push(h.year)
              byCompetition.set(h.competition_name, years)
            }

            return (
              <div key={team.id} className="honours-group">
                <h3>
                  {SPORT_ICONS[team.sport_code]} {SPORT_LABELS[team.sport_code]}
                </h3>
                <ul className="honours-list">
                  {[...byCompetition.entries()].map(([competition, years]) => (
                    <li key={competition}>
                      <strong>
                        {competition} ({years.length})
                      </strong>
                      <span className="muted small">{years.sort((a, b) => b - a).join(', ')}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )
          })}
        </section>
      )}
    </div>
  )
}
