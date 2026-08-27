import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import GroundCard, { type GroundCardData } from '../components/GroundCard'

type Row = { id: string; name: string; capacity: number | null; county_id: string; is_primary: boolean }
type County = { id: string; name: string }

export default function Grounds() {
  const { user } = useAuth()
  const [allGrounds, setAllGrounds] = useState<Row[]>([])
  const [counties, setCounties] = useState<Map<string, string>>(new Map())
  const [visitedIds, setVisitedIds] = useState<Set<string>>(new Set())
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false

    async function load() {
      const [{ data: groundData }, { data: countyData }] = await Promise.all([
        supabase.from('grounds').select('id, name, capacity, county_id, is_primary').order('name'),
        supabase.from('counties').select('id, name'),
      ])
      if (cancelled) return
      setAllGrounds(groundData ?? [])
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

  // Matches GroundsView.swift's `grounds = mapGrounds.filter(\.isPrimary)` --
  // alternate grounds still exist in the database (and would populate a map
  // view, same as iOS's mapGrounds) but the browsable list only shows each
  // county's main ground.
  const primaryGrounds = useMemo(() => allGrounds.filter((g) => g.is_primary), [allGrounds])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return primaryGrounds
    return primaryGrounds.filter(
      (g) => g.name.toLowerCase().includes(q) || (counties.get(g.county_id) ?? '').toLowerCase().includes(q),
    )
  }, [primaryGrounds, counties, search])

  const cards: GroundCardData[] = filtered.map((g) => ({
    id: g.id,
    name: g.name,
    countyName: counties.get(g.county_id) ?? '',
    capacity: g.capacity,
    visited: visitedIds.has(g.id),
  }))

  const visitedPrimaryCount = primaryGrounds.filter((g) => visitedIds.has(g.id)).length

  return (
    <div className="page">
      <h1>Grounds</h1>
      <p className="muted">
        {visitedPrimaryCount > 0
          ? `You've visited ${visitedPrimaryCount} of ${primaryGrounds.length} grounds.`
          : 'Browse every intercounty ground and check in when you visit.'}
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
