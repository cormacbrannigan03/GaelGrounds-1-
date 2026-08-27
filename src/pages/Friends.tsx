import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'

type Profile = { id: string; display_name: string | null; avatar_url: string | null }
type FriendEntry = { friendshipId: string; profile: Profile }
type FriendRequest = { friendshipId: string; profile: Profile }

export default function Friends() {
  const { user } = useAuth()
  const [isPremium, setIsPremium] = useState(false)
  const [friends, setFriends] = useState<FriendEntry[]>([])
  const [pending, setPending] = useState<FriendRequest[]>([])
  const [sent, setSent] = useState<FriendRequest[]>([])
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Profile[]>([])
  const [searching, setSearching] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  async function load() {
    if (!user) return
    setLoading(true)

    const [{ data: profile }, { data: friendshipRows }] = await Promise.all([
      supabase.from('user_profiles').select('is_premium').eq('id', user.id).single(),
      supabase.from('friendships').select('*').or(`requester_id.eq.${user.id},addressee_id.eq.${user.id}`),
    ])

    setIsPremium(profile?.is_premium ?? false)

    const rows = friendshipRows ?? []
    const otherIds = [
      ...new Set(rows.map((r) => (r.requester_id === user.id ? r.addressee_id : r.requester_id))),
    ]
    const { data: profileRows } = otherIds.length
      ? await supabase.from('user_profiles').select('id, display_name, avatar_url').in('id', otherIds)
      : { data: [] as Profile[] }
    const profileById = new Map((profileRows ?? []).map((p) => [p.id, p]))

    setFriends(
      rows
        .filter((r) => r.status === 'accepted')
        .map((r) => {
          const otherId = r.requester_id === user.id ? r.addressee_id : r.requester_id
          return { friendshipId: r.id, profile: profileById.get(otherId) }
        })
        .filter((f): f is FriendEntry => Boolean(f.profile)),
    )
    setPending(
      rows
        .filter((r) => r.status === 'pending' && r.addressee_id === user.id)
        .map((r) => ({ friendshipId: r.id, profile: profileById.get(r.requester_id) }))
        .filter((f): f is FriendRequest => Boolean(f.profile)),
    )
    setSent(
      rows
        .filter((r) => r.status === 'pending' && r.requester_id === user.id)
        .map((r) => ({ friendshipId: r.id, profile: profileById.get(r.addressee_id) }))
        .filter((f): f is FriendRequest => Boolean(f.profile)),
    )
    setLoading(false)
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user])

  async function search(q: string) {
    setQuery(q)
    const trimmed = q.trim()
    if (!trimmed || !user) {
      setResults([])
      return
    }
    setSearching(true)
    const { data } = await supabase
      .from('user_profiles')
      .select('id, display_name, avatar_url')
      .ilike('display_name', `%${trimmed}%`)
      .neq('id', user.id)
      .limit(20)
    setResults(data ?? [])
    setSearching(false)
  }

  async function sendRequest(addresseeId: string) {
    if (!user) return
    setError(null)
    const { error: insertError } = await supabase
      .from('friendships')
      .insert({ requester_id: user.id, addressee_id: addresseeId })
    if (insertError) {
      setError(
        isPremium
          ? "Couldn't send that request — try again."
          : 'Sending friend requests requires GaelGrounds Premium — visit the Premium page to upgrade.',
      )
      return
    }
    await load()
  }

  async function respond(friendshipId: string, accept: boolean) {
    await supabase.from('friendships').update({ status: accept ? 'accepted' : 'declined' }).eq('id', friendshipId)
    await load()
  }

  async function removeFriendship(friendshipId: string) {
    await supabase.from('friendships').delete().eq('id', friendshipId)
    await load()
  }

  if (!user) return null

  return (
    <div className="page">
      <div className="page-header">
        <h1>Friends</h1>
      </div>

      <section>
        <h2>Find people</h2>
        <input
          className="search-input"
          value={query}
          onChange={(e) => search(e.target.value)}
          placeholder="Search by display name"
        />
        {error && <p className="muted small error-text">{error}</p>}
        {searching && <p className="muted small">Searching…</p>}
        {results.length > 0 && (
          <ul className="history-list">
            {results.map((p) => (
              <li key={p.id} className="history-list-item">
                <span>{p.display_name ?? 'A fan'}</span>
                <button className="btn btn-outline btn-sm" onClick={() => sendRequest(p.id)}>
                  Add friend
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      {loading ? (
        <p className="muted">Loading…</p>
      ) : (
        <>
          {pending.length > 0 && (
            <section>
              <h2>Requests</h2>
              <ul className="history-list">
                {pending.map((r) => (
                  <li key={r.friendshipId} className="history-list-item">
                    <span>{r.profile.display_name ?? 'A fan'}</span>
                    <span className="request-actions">
                      <button className="btn btn-outline btn-sm" onClick={() => respond(r.friendshipId, true)}>
                        Accept
                      </button>
                      <button className="btn btn-ghost btn-sm" onClick={() => respond(r.friendshipId, false)}>
                        Decline
                      </button>
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          )}

          {sent.length > 0 && (
            <section>
              <h2>Sent</h2>
              <ul className="history-list">
                {sent.map((r) => (
                  <li key={r.friendshipId} className="history-list-item">
                    <span>{r.profile.display_name ?? 'A fan'}</span>
                    <span className="muted small">Pending</span>
                  </li>
                ))}
              </ul>
            </section>
          )}

          <section>
            <h2>Your friends</h2>
            {friends.length === 0 ? (
              <p className="muted">No friends yet — search above to send a request.</p>
            ) : (
              <ul className="history-list">
                {friends.map((f) => (
                  <li key={f.friendshipId} className="history-list-item">
                    <span>{f.profile.display_name ?? 'A fan'}</span>
                    <button className="btn btn-ghost btn-sm" onClick={() => removeFriendship(f.friendshipId)}>
                      Remove
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </>
      )}

      <Link to="/profile" className="link">
        ← Back to profile
      </Link>
    </div>
  )
}
