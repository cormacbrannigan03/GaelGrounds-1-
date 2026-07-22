import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import GroundCard, { type GroundCardData } from '../components/GroundCard'

type Row = { id: string; name: string; capacity: number | null; county_id: string }
type County = { id: string; name: string }

export default function Grounds() {
  const { user } = useAuth()
  const [grounds, setGrounds] = useState<Row[]>([])
  const [counties, setCounties] = useState<Map<string, string>>(new Map())
  const [visitedIds, setVisitedIds] = useState<Set<string>>(new Set())
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false

    async function load() {
      const [{ data: groundData }, { data: countyData }] = await Promise.all([
        supabase.from('grounds').select('id, name, capacity, county_id').order('name'),
        supabase.from('counties').select('id, name'),
      ])
      if (cancelled) return
      setGrounds(groundData ?? [])
      setCounties(new Map((countyData ?? []).map((c) => [c.id, c.name])))

      if (user) {
        const { data: visits } = await supabase.from('user_visits').select('ground_id').eq('user_id', user.id)
        if (!cancelled) setVisitedIds(new Set((visits ?? []).map((v) => v.ground_id)))
      }
      if (!cancelled) setLoading(false)
    }

    load()
    return () => {
      cancelled = true
    }
  }, [user])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return grounds
    return grounds.filter(
      (g) => g.name.toLowerCase().includes(q) || (counties.get(g.county_id) ?? '').toLowerCase().includes(q),
    )
  }, [grounds, counties, search])

  const cards: GroundCardData[] = filtered.map((g) => ({
    id: g.id,
    name: g.name,
    countyName: counties.get(g.county_id) ?? '',
    capacity: g.capacity,
    visited: visitedIds.has(g.id),
  }))

  return (
    <div className="page">
      <h1>Grounds</h1>
      <p className="muted">
        {visitedIds.size > 0 ? `You've visited ${visitedIds.size} of ${grounds.length} grounds.` : 'Browse every intercounty ground and check in when you visit.'}
      </p>
      <input
        className="search-input"
        placeholder="Search grounds or counties…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />

      {loading ? (
        <p className="muted">Loading grounds…</p>
      ) : (
        <div className="card-grid">
          {cards.map((g) => (
            <GroundCard key={g.id} ground={g} />
          ))}
        </div>
      )}
    </div>
  )
}
