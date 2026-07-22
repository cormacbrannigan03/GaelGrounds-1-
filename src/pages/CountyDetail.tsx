import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import type { Enums } from '../lib/database.types'
import { SPORT_LABELS, SPORT_ICONS } from '../lib/format'

type County = { id: string; name: string; province: Enums<'province'>; primary_colour: string | null }
type TeamRow = { id: string; sport_code: Enums<'sport_code'>; founded_year: number | null; current_manager: string | null }
type GroundRow = { id: string; name: string; capacity: number | null }
type HonourRow = { id: string; competition_name: string; year: number; honour_type: Enums<'honour_type'> }

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
        supabase.from('counties').select('id, name, province, primary_colour').eq('id', id!).single(),
        supabase.from('county_teams').select('id, sport_code, founded_year, current_manager').eq('county_id', id!),
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
          .select('id, competition_name, year, honour_type')
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

  if (loading) return <div className="page"><p className="muted">Loading…</p></div>
  if (!county) return <div className="page"><p>County not found.</p></div>

  return (
    <div className="page">
      <div className="page-header" style={{ borderColor: county.primary_colour ?? undefined }}>
        <h1>{county.name}</h1>
        <p className="muted">{county.province}</p>
      </div>

      <section>
        <h2>Intercounty teams</h2>
        <div className="card-grid">
          {teams.map((t) => (
            <div key={t.id} className="card">
              <h3>
                {SPORT_ICONS[t.sport_code]} {SPORT_LABELS[t.sport_code]}
              </h3>
              {t.founded_year && <p className="muted small">Founded {t.founded_year}</p>}
              {t.current_manager && <p className="muted small">Manager: {t.current_manager}</p>}
            </div>
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
          <h2>Honours</h2>
          <ul className="honours-list">
            {honours.map((h) => (
              <li key={h.id}>
                <strong>{h.year}</strong> — {h.competition_name}
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  )
}
