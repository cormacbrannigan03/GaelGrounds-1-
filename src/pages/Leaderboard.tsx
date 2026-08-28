import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import {
  fetchLeaderboardRawData,
  buildLeaderboardEntries,
  type LeaderboardEntry,
  type LeaderboardRawData,
  type SportFilter,
  type Tier,
} from '../lib/leaderboard'
import { SPORT_ICONS, SPORT_LABELS } from '../lib/format'

type SortKey = 'matches' | 'grounds'
type Scope = 'everyone' | 'friends'
type TabKey = 'overall' | 'myCounty' | 'Leinster' | 'Munster' | 'Connacht' | 'Ulster' | 'bronze' | 'silver' | 'gold'

const PROVINCE_TABS: TabKey[] = ['Ulster', 'Munster', 'Leinster', 'Connacht']
const TIER_TABS: { key: TabKey; tier: Tier; label: string }[] = [
  { key: 'bronze', tier: 'bronze', label: 'Most Bronze' },
  { key: 'silver', tier: 'silver', label: 'Most Silver' },
  { key: 'gold', tier: 'gold', label: 'Top Gold' },
]
const SPORT_OPTIONS: SportFilter[] = ['combined', 'gaelic_football', 'hurling']

function sortedOverall(entries: LeaderboardEntry[], sortBy: SortKey) {
  return [...entries].sort((a, b) =>
    sortBy === 'matches'
      ? b.matchCount - a.matchCount || b.groundCount - a.groundCount
      : b.groundCount - a.groundCount || b.matchCount - a.matchCount,
  )
}

// "My County" ranks by matches attended involving that county specifically,
// not overall match count -- otherwise the tab just filters who appears
// while still crediting people for matches that had nothing to do with the
// county they support.
function sortedByCounty(entries: LeaderboardEntry[], sortBy: SortKey) {
  return [...entries].sort((a, b) =>
    sortBy === 'matches'
      ? b.supportedCountyMatchCount - a.supportedCountyMatchCount || b.groundCount - a.groundCount
      : b.groundCount - a.groundCount || b.supportedCountyMatchCount - a.supportedCountyMatchCount,
  )
}

export default function Leaderboard() {
  const { user, supportedCounty } = useAuth()
  const [rawData, setRawData] = useState<LeaderboardRawData | null>(null)
  const [friendIds, setFriendIds] = useState<Set<string>>(new Set())
  const [isPremium, setIsPremium] = useState(false)
  const [sortBy, setSortBy] = useState<SortKey>('matches')
  const [scope, setScope] = useState<Scope>('everyone')
  const [sport, setSport] = useState<SportFilter>('combined')
  const [tab, setTab] = useState<TabKey>('overall')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false

    async function load() {
      setLoading(true)
      const [loadedRawData, ownProfile, friendshipRows] = await Promise.all([
        fetchLeaderboardRawData(),
        user ? supabase.from('user_profiles').select('is_premium').eq('id', user.id).single() : Promise.resolve({ data: null }),
        user
          ? supabase
              .from('friendships')
              .select('requester_id, addressee_id, status')
              .or(`requester_id.eq.${user.id},addressee_id.eq.${user.id}`)
              .eq('status', 'accepted')
          : Promise.resolve({ data: [] as { requester_id: string; addressee_id: string }[] }),
      ])

      if (cancelled) return
      setRawData(loadedRawData)
      setIsPremium(ownProfile?.data?.is_premium ?? false)
      setFriendIds(
        new Set((friendshipRows.data ?? []).map((r) => (r.requester_id === user?.id ? r.addressee_id : r.requester_id))),
      )
      setLoading(false)
    }

    load()
    return () => {
      cancelled = true
    }
  }, [user])

  // Recomputed client-side from already-fetched data -- switching Combined/
  // Football/Hurling feels instant, same as every other tab on this page,
  // instead of re-querying Supabase on every tap.
  const entries = useMemo(() => (rawData ? buildLeaderboardEntries(rawData, sport) : []), [rawData, sport])

  const scoped = useMemo(
    () => (scope === 'friends' ? entries.filter((e) => e.id === user?.id || friendIds.has(e.id)) : entries),
    [entries, scope, friendIds, user],
  )

  const displayed = useMemo(() => {
    if (tab === 'myCounty') {
      if (!supportedCounty) return []
      return sortedByCounty(
        scoped.filter((e) => e.supportedCountyId === supportedCounty.id),
        sortBy,
      )
    }
    if ((PROVINCE_TABS as string[]).includes(tab)) {
      return [...scoped]
        .filter((e) => (e.provinceMatchCounts[tab] ?? 0) > 0)
        .sort((a, b) => (b.provinceMatchCounts[tab] ?? 0) - (a.provinceMatchCounts[tab] ?? 0))
    }
    const tierTab = TIER_TABS.find((t) => t.key === tab)
    if (tierTab) {
      return [...scoped]
        .filter((e) => e.tierCounts[tierTab.tier] > 0)
        .sort((a, b) => b.tierCounts[tierTab.tier] - a.tierCounts[tierTab.tier])
    }
    return sortedOverall(scoped, sortBy)
  }, [scoped, tab, sortBy, supportedCounty])

  const rankLabel = (rank: number) => (rank === 1 ? '🥇' : rank === 2 ? '🥈' : rank === 3 ? '🥉' : `${rank}`)

  function primaryCount(entry: LeaderboardEntry) {
    const tierTab = TIER_TABS.find((t) => t.key === tab)
    if (tierTab) return entry.tierCounts[tierTab.tier]
    if ((PROVINCE_TABS as string[]).includes(tab)) return entry.provinceMatchCounts[tab] ?? 0
    if (tab === 'myCounty' && sortBy === 'matches') return entry.supportedCountyMatchCount
    return sortBy === 'matches' ? entry.matchCount : entry.groundCount
  }

  function primaryLabel() {
    const tierTab = TIER_TABS.find((t) => t.key === tab)
    if (tierTab) return tierTab.tier
    if ((PROVINCE_TABS as string[]).includes(tab)) return 'matches'
    return sortBy === 'matches' ? 'matches' : 'grounds'
  }

  function secondaryText(entry: LeaderboardEntry) {
    const tierTab = TIER_TABS.find((t) => t.key === tab)
    if (tierTab) {
      return TIER_TABS.filter((t) => t.tier !== tierTab.tier)
        .map((t) => `${entry.tierCounts[t.tier]} ${t.tier}`)
        .join(' · ')
    }
    if ((PROVINCE_TABS as string[]).includes(tab)) {
      return `${entry.matchCount} total · ${entry.groundCount} grounds`
    }
    if (tab === 'myCounty') {
      return sortBy === 'matches' ? `${entry.groundCount} grounds` : `${entry.supportedCountyMatchCount} matches`
    }
    return sortBy === 'matches' ? `${entry.groundCount} grounds` : `${entry.matchCount} matches`
  }

  const emptyMessage = (() => {
    if (scope === 'friends' && friendIds.size === 0) return 'Add some friends to see how you compare against them.'
    if (tab === 'myCounty') {
      return supportedCounty
        ? `No ${supportedCounty.name} supporters have checked in yet.`
        : 'Choose a supported county on your profile to unlock this leaderboard.'
    }
    if ((PROVINCE_TABS as string[]).includes(tab)) return `No ${tab} matches attended yet.`
    const tierTab = TIER_TABS.find((t) => t.key === tab)
    if (tierTab) return `No ${tierTab.tier} achievements unlocked yet.`
    return 'No activity yet. Be the first to check in!'
  })()

  const TABS: { key: TabKey; label: string }[] = [
    { key: 'overall', label: 'Overall' },
    { key: 'myCounty', label: supportedCounty?.name ?? 'My County' },
    ...PROVINCE_TABS.map((p) => ({ key: p, label: p })),
    ...TIER_TABS.map((t) => ({ key: t.key, label: t.label })),
  ]

  return (
    <div className="page">
      <div className="page-header">
        <h1>Leaderboard</h1>
      </div>

      {user && !isPremium && (
        <Link to="/premium" className="card leaderboard-premium-banner">
          Go Premium to appear on the leaderboard →
        </Link>
      )}

      <p className="muted small">Only Premium members who've opted in on their Profile appear on the leaderboard.</p>

      <div className="filter-tabs">
        {SPORT_OPTIONS.map((s) => (
          <button key={s} className={sport === s ? 'active' : ''} onClick={() => setSport(s)}>
            {s === 'combined' ? '🏐🏑 Combined' : `${SPORT_ICONS[s]} ${SPORT_LABELS[s]}`}
          </button>
        ))}
      </div>

      <div className="leaderboard-tabs">
        {TABS.map((t) => (
          <button key={t.key} className={tab === t.key ? 'active' : ''} onClick={() => setTab(t.key)}>
            {t.label}
          </button>
        ))}
      </div>

      <div className="segmented">
        <button className={scope === 'everyone' ? 'active' : ''} onClick={() => setScope('everyone')}>
          Everyone
        </button>
        <button className={scope === 'friends' ? 'active' : ''} onClick={() => setScope('friends')}>
          Friends
        </button>
      </div>

      {(tab === 'overall' || tab === 'myCounty') && (
        <div className="segmented">
          <button className={sortBy === 'matches' ? 'active' : ''} onClick={() => setSortBy('matches')}>
            Matches
          </button>
          <button className={sortBy === 'grounds' ? 'active' : ''} onClick={() => setSortBy('grounds')}>
            Grounds
          </button>
        </div>
      )}

      {loading ? (
        <p className="muted">Loading…</p>
      ) : displayed.length === 0 ? (
        <p className="muted">{emptyMessage}</p>
      ) : (
        <ul className="leaderboard-list">
          {displayed.map((entry, i) => (
            <li key={entry.id} className={entry.id === user?.id ? 'leaderboard-row current-user' : 'leaderboard-row'}>
              <span className="leaderboard-rank">{rankLabel(i + 1)}</span>
              <span className="leaderboard-name-block">
                <Link
                  to={entry.id === user?.id ? '/profile' : `/friends/${entry.id}`}
                  className="leaderboard-name"
                >
                  {entry.displayName}
                </Link>
                <span className="muted small">{secondaryText(entry)}</span>
              </span>
              <span className="leaderboard-count">
                <strong>{primaryCount(entry)}</strong>
                <span className="muted small">{primaryLabel()}</span>
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
