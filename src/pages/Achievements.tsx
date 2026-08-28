import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { useAuth } from '../context/AuthContext'
import { supabase } from '../lib/supabaseClient'
import {
  loadAchievementState,
  tierInfo,
  MAX_PINNED_ACHIEVEMENTS,
  type AchievementDefinition,
  type AchievementState,
} from '../lib/achievements'
import { formatShortDate } from '../lib/format'

type CountyRow = { id: string; name: string; province: string }

const SUPPORTER_RULE_TYPES = new Set(['county_home_match', 'county_away_match'])
const GROUND_RULE_TYPES = new Set(['ground_visit_count', 'all_provinces_visited', 'country_grounds_complete'])
const PROVINCE_ORDER = ['Leinster', 'Munster', 'Connacht', 'Ulster']

export default function Achievements() {
  const { user, supportedCounty } = useAuth()
  const [state, setState] = useState<AchievementState | null>(null)
  const [counties, setCounties] = useState<CountyRow[]>([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState<'unlocked' | 'locked'>('unlocked')
  const [pinLimitMessage, setPinLimitMessage] = useState<string | null>(null)
  const [expanded, setExpanded] = useState<Set<string>>(new Set(['supporters']))

  useEffect(() => {
    if (!user) return
    let cancelled = false
    Promise.all([loadAchievementState(user.id), supabase.from('counties').select('id, name, province')]).then(
      ([achievementState, { data: countyRows }]) => {
        if (cancelled) return
        setState(achievementState)
        setCounties(countyRows ?? [])
        setLoading(false)
      },
    )
    return () => {
      cancelled = true
    }
  }, [user])

  const countyNameById = useMemo(() => new Map(counties.map((c) => [c.id, c.name])), [counties])
  const provinceByCountyId = useMemo(() => new Map(counties.map((c) => [c.id, c.province])), [counties])

  const unlocked = useMemo(() => {
    if (!state) return []
    return state.defs
      .filter((d) => state.unlockedByDefId.has(d.id))
      .map((d) => ({ def: d, row: state.unlockedByDefId.get(d.id)! }))
      .sort((a, b) => b.row.unlocked_at.localeCompare(a.row.unlocked_at))
  }, [state])

  const locked = useMemo(() => {
    if (!state) return []
    return state.defs.filter((d) => !state.unlockedByDefId.has(d.id))
  }, [state])

  const supporterLocked = useMemo(() => {
    if (!supportedCounty) return []
    return locked
      .filter((d) => (d.rule_params?.county_id as string | undefined) === supportedCounty.id && SUPPORTER_RULE_TYPES.has(d.rule_type))
      .sort((a, b) => a.title.localeCompare(b.title))
  }, [locked, supportedCounty])

  const groundsLocked = useMemo(
    () => locked.filter((d) => !d.rule_params?.county_id && !d.rule_params?.province && GROUND_RULE_TYPES.has(d.rule_type)),
    [locked],
  )

  const matchesLocked = useMemo(
    () => locked.filter((d) => !d.rule_params?.county_id && !d.rule_params?.province && !GROUND_RULE_TYPES.has(d.rule_type)),
    [locked],
  )

  const countyGroups = useMemo(() => {
    const byCounty = new Map<string, AchievementDefinition[]>()
    for (const d of locked) {
      const countyId = d.rule_params?.county_id as string | undefined
      if (!countyId) continue
      byCounty.set(countyId, [...(byCounty.get(countyId) ?? []), d])
    }
    return [...byCounty.entries()]
      .map(([countyId, defs]) => ({
        countyId,
        countyName: countyNameById.get(countyId) ?? 'Unknown county',
        province: provinceByCountyId.get(countyId) ?? null,
        defs: defs.sort((a, b) => a.title.localeCompare(b.title)),
      }))
      .sort((a, b) => a.countyName.localeCompare(b.countyName))
  }, [locked, countyNameById, provinceByCountyId])

  const provinceGroups = useMemo(() => {
    const own = new Map(locked.filter((d) => d.rule_params?.province).map((d) => [d.rule_params!.province as string, d]))
    return PROVINCE_ORDER.map((province) => ({
      province,
      own: own.get(province) ?? null,
      counties: countyGroups.filter((c) => c.province === province),
    })).filter((g) => g.own || g.counties.length > 0)
  }, [locked, countyGroups])

  async function togglePinned(achievementId: string, rowId: string, currentlyPinned: boolean) {
    if (!state) return
    const newValue = !currentlyPinned
    if (newValue && [...state.unlockedByDefId.values()].filter((r) => r.pinned).length >= MAX_PINNED_ACHIEVEMENTS) {
      setPinLimitMessage(`You can only feature ${MAX_PINNED_ACHIEVEMENTS} achievements on your profile — unstar one first.`)
      return
    }
    setPinLimitMessage(null)
    setState((prev) => {
      if (!prev) return prev
      const next = new Map(prev.unlockedByDefId)
      next.set(achievementId, { ...next.get(achievementId)!, pinned: newValue })
      return { ...prev, unlockedByDefId: next }
    })
    const { error } = await supabase.from('user_achievements').update({ pinned: newValue }).eq('id', rowId)
    if (error) {
      setState((prev) => {
        if (!prev) return prev
        const next = new Map(prev.unlockedByDefId)
        next.set(achievementId, { ...next.get(achievementId)!, pinned: currentlyPinned })
        return { ...prev, unlockedByDefId: next }
      })
    }
  }

  function toggleSection(key: string) {
    setExpanded((prev) => {
      const next = new Set(prev)
      if (next.has(key)) next.delete(key)
      else next.add(key)
      return next
    })
  }

  if (!user) return null

  return (
    <div className="page">
      <div className="page-header">
        <h1>Achievements</h1>
        {!loading && (
          <p className="muted">
            {unlocked.length} of {unlocked.length + locked.length} unlocked
          </p>
        )}
      </div>

      {loading ? (
        <p className="muted">Loading achievements…</p>
      ) : (
        <>
          <div className="segmented">
            <button className={tab === 'unlocked' ? 'active' : ''} onClick={() => setTab('unlocked')}>
              Unlocked ({unlocked.length})
            </button>
            <button className={tab === 'locked' ? 'active' : ''} onClick={() => setTab('locked')}>
              Locked ({locked.length})
            </button>
          </div>

          {pinLimitMessage && <p className="muted small error-text">{pinLimitMessage}</p>}

          {tab === 'unlocked' ? (
            unlocked.length === 0 ? (
              <p className="muted">No achievements yet — check in to games to start unlocking achievements.</p>
            ) : (
              <div className="card-grid">
                {unlocked.map(({ def, row }) => {
                  const tier = state ? tierInfo(def, state) : null
                  return (
                    <div key={def.id} className="card achievement-card">
                      <div className="achievement-card-top">
                        <h3>🏆 {def.title}</h3>
                        <button
                          className="star-toggle"
                          onClick={() => togglePinned(def.id, row.id, row.pinned)}
                          aria-label={row.pinned ? 'Remove from profile favourites' : 'Add to profile favourites'}
                        >
                          {row.pinned ? '★' : '☆'}
                        </button>
                      </div>
                      <p className="muted small">{def.description}</p>
                      {tier && (
                        <p className={`achievement-tier tier-${tier.tier}`}>
                          {tier.tier === 'standard'
                            ? `${tier.count} ${tier.kindLabel} games`
                            : `${tier.tier[0].toUpperCase()}${tier.tier.slice(1)} · ${tier.count} ${tier.kindLabel} games`}
                        </p>
                      )}
                      <p className="muted small">Unlocked {formatShortDate(row.unlocked_at)}</p>
                    </div>
                  )
                })}
              </div>
            )
          ) : locked.length === 0 ? (
            <p className="muted">All achievements unlocked! You've earned everything there is right now.</p>
          ) : (
            <div className="achievements-locked-groups">
              {supporterLocked.length > 0 && (
                <LockedSection
                  title="Supporters Unlocks"
                  count={supporterLocked.length}
                  expanded={expanded.has('supporters')}
                  onToggle={() => toggleSection('supporters')}
                >
                  {supporterLocked.map((d) => (
                    <LockedCard key={d.id} def={d} />
                  ))}
                </LockedSection>
              )}

              {groundsLocked.length > 0 && (
                <LockedSection
                  title="Grounds"
                  count={groundsLocked.length}
                  expanded={expanded.has('grounds')}
                  onToggle={() => toggleSection('grounds')}
                >
                  {groundsLocked.map((d) => (
                    <LockedCard key={d.id} def={d} />
                  ))}
                </LockedSection>
              )}

              {matchesLocked.length > 0 && (
                <LockedSection
                  title="Matches"
                  count={matchesLocked.length}
                  expanded={expanded.has('matches')}
                  onToggle={() => toggleSection('matches')}
                >
                  {matchesLocked.map((d) => (
                    <LockedCard key={d.id} def={d} />
                  ))}
                </LockedSection>
              )}

              {countyGroups.length > 0 && (
                <LockedSection
                  title="Counties"
                  count={countyGroups.reduce((n, c) => n + c.defs.length, 0)}
                  expanded={expanded.has('counties')}
                  onToggle={() => toggleSection('counties')}
                >
                  {countyGroups.flatMap((c) => c.defs).map((d) => (
                    <LockedCard key={d.id} def={d} />
                  ))}
                </LockedSection>
              )}

              {provinceGroups.length > 0 && (
                <LockedSection
                  title="Provinces"
                  count={provinceGroups.length}
                  expanded={expanded.has('provinces')}
                  onToggle={() => toggleSection('provinces')}
                  layout="stack"
                >
                  {provinceGroups.map((g) => (
                    <div key={g.province} className="province-group">
                      <h4>{g.province}</h4>
                      <div className="card-grid locked-section-grid">
                        {g.own && <LockedCard def={g.own} />}
                        {g.counties.flatMap((c) => c.defs).map((d) => (
                          <LockedCard key={d.id} def={d} />
                        ))}
                      </div>
                    </div>
                  ))}
                </LockedSection>
              )}
            </div>
          )}
        </>
      )}
    </div>
  )
}

function LockedSection({
  title,
  count,
  expanded,
  onToggle,
  layout = 'grid',
  children,
}: {
  title: string
  count: number
  expanded: boolean
  onToggle: () => void
  layout?: 'grid' | 'stack'
  children: ReactNode
}) {
  return (
    <div className="results-year">
      <button className="results-group-header" onClick={onToggle}>
        <span>
          {title} <span className="muted small">({count})</span>
        </span>
        <span>{expanded ? '▾' : '▸'}</span>
      </button>
      {expanded && (
        <div className={layout === 'grid' ? 'card-grid locked-section-grid' : 'province-group-stack'}>{children}</div>
      )}
    </div>
  )
}

function LockedCard({ def }: { def: AchievementDefinition }) {
  return (
    <div className="card achievement-card locked">
      <h3>🔒 {def.title}</h3>
      <p className="muted small">{def.description}</p>
    </div>
  )
}
