import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'

type Entry = { id: string; displayName: string; matchCount: number; groundCount: number }
type SortKey = 'matches' | 'grounds'
type Scope = 'everyone' | 'friends'

export default function Leaderboard() {
  const { user } = useAuth()
  const [entries, setEntries] = useState<Entry[]>([])
  const [friendIds, setFriendIds] = useState<Set<string>>(new Set())
  const [sortBy, setSortBy] = useState<SortKey>('matches')
  const [scope, setScope] = useState<Scope>('everyone')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false

    async function load() {
      setLoading(true)
      const [{ data: profiles }, { data: attendance }, { data: visits }] = await Promise.all([
        supabase.from('user_profiles').select('id, display_name, is_premium'),
        supabase.from('user_match_attendance').select('user_id'),
        supabase.from('user_visits').select('user_id, ground_id'),
      ])

      if (cancelled) return

      const matchCounts = new Map<string, number>()
      for (const a of attendance ?? []) matchCounts.set(a.user_id, (matchCounts.get(a.user_id) ?? 0) + 1)

      const groundIdsByUser = new Map<string, Set<string>>()
      for (const v of visits ?? []) {
        if (!groundIdsByUser.has(v.user_id)) groundIdsByUser.set(v.user_id, new Set())
        groundIdsByUser.get(v.user_id)!.add(v.ground_id)
      }

      // Free accounts can browse the leaderboard but never appear on it --
      // only premium profiles are ranked, matching the iOS app.
      const ranked = (profiles ?? [])
        .filter((p) => p.is_premium)
        .map((p) => ({
          id: p.id,
          displayName: p.display_name ?? 'Anonymous',
          matchCount: matchCounts.get(p.id) ?? 0,
          groundCount: groundIdsByUser.get(p.id)?.size ?? 0,
        }))

      if (!cancelled) setEntries(ranked)

      if (user) {
        const { data: friendshipRows } = await supabase
          .from('friendships')
          .select('requester_id, addressee_id, status')
          .or(`requester_id.eq.${user.id},addressee_id.eq.${user.id}`)
          .eq('status', 'accepted')
        const ids = new Set(
          (friendshipRows ?? []).map((r) => (r.requester_id === user.id ? r.addressee_id : r.requester_id)),
        )
        if (!cancelled) setFriendIds(ids)
      }

      if (!cancelled) setLoading(false)
    }

    load()
    return () => {
      cancelled = true
    }
  }, [user])

  const scoped = scope === 'friends' ? entries.filter((e) => e.id === user?.id || friendIds.has(e.id)) : entries
  const displayed = [...scoped].sort((a, b) =>
    sortBy === 'matches'
      ? b.matchCount - a.matchCount || b.groundCount - a.groundCount
      : b.groundCount - a.groundCount || b.matchCount - a.matchCount,
  )

  const rankLabel = (rank: number) => (rank === 1 ? '🥇' : rank === 2 ? '🥈' : rank === 3 ? '🥉' : `${rank}`)

  return (
    <div className="page">
      <div className="page-header">
        <h1>Leaderboard</h1>
      </div>

      <p className="muted small">Only Premium members appear on the leaderboard.</p>

      <div className="segmented">
        <button className={scope === 'everyone' ? 'active' : ''} onClick={() => setScope('everyone')}>
          Everyone
        </button>
        <button className={scope === 'friends' ? 'active' : ''} onClick={() => setScope('friends')}>
          Friends
        </button>
      </div>

      <div className="segmented">
        <button className={sortBy === 'matches' ? 'active' : ''} onClick={() => setSortBy('matches')}>
          Matches
        </button>
        <button className={sortBy === 'grounds' ? 'active' : ''} onClick={() => setSortBy('grounds')}>
          Grounds
        </button>
      </div>

      {loading ? (
        <p className="muted">Loading…</p>
      ) : displayed.length === 0 ? (
        <p className="muted">
          {scope === 'friends' ? 'Add some friends to see how you compare against them.' : 'No activity yet. Be the first to check in!'}
        </p>
      ) : (
        <ul className="leaderboard-list">
          {displayed.map((entry, i) => (
            <li key={entry.id} className={entry.id === user?.id ? 'leaderboard-row current-user' : 'leaderboard-row'}>
              <span className="leaderboard-rank">{rankLabel(i + 1)}</span>
              <span className="leaderboard-name">{entry.displayName}</span>
              <span className="leaderboard-count">
                <strong>{sortBy === 'matches' ? entry.matchCount : entry.groundCount}</strong>
                <span className="muted small">{sortBy === 'matches' ? 'matches' : 'grounds'}</span>
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
