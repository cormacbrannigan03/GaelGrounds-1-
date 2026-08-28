import { useEffect, useState } from 'react'
import { useParams, Link, Navigate } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import { formatMatchDate, formatShortDate } from '../lib/format'
import { useCountyPageBackground } from '../hooks/useCountyPageBackground'

type Profile = { id: string; display_name: string | null; best_match_id: string | null; supported_county_id: string | null }
type County = { id: string; name: string; primary_colour: string | null; secondary_colour: string | null }
type AchievementRow = {
  id: string
  title: string
  description: string
  unlockedAt: string
  pinned: boolean
}
type BestGame = {
  matchId: string
  competition: string | null
  playedAt: string | null
  homeName: string
  awayName: string
  homeScore: string | null
  awayScore: string | null
  groundName: string | null
}

type FriendStatus = 'self' | 'none' | 'sent' | 'received' | 'friends'

export default function FriendProfile() {
  const { id } = useParams<{ id: string }>()
  const { user } = useAuth()
  const [profile, setProfile] = useState<Profile | null>(null)
  const [county, setCounty] = useState<County | null>(null)
  const [visitCount, setVisitCount] = useState(0)
  const [matchCount, setMatchCount] = useState(0)
  const [totalAchievementCount, setTotalAchievementCount] = useState(0)
  const [favouriteAchievements, setFavouriteAchievements] = useState<AchievementRow[]>([])
  const [bestGame, setBestGame] = useState<BestGame | null>(null)
  const [loading, setLoading] = useState(true)

  const [friendStatus, setFriendStatus] = useState<FriendStatus>('none')
  const [friendshipId, setFriendshipId] = useState<string | null>(null)
  const [isPremium, setIsPremium] = useState(false)
  const [friendError, setFriendError] = useState<string | null>(null)
  const [friendBusy, setFriendBusy] = useState(false)

  useCountyPageBackground(county?.primary_colour, county?.secondary_colour)

  async function loadFriendStatus() {
    if (!user || !id) return
    if (id === user.id) {
      setFriendStatus('self')
      return
    }
    const [{ data: ownProfile }, { data: rows }] = await Promise.all([
      supabase.from('user_profiles').select('is_premium').eq('id', user.id).single(),
      supabase
        .from('friendships')
        .select('id, requester_id, addressee_id, status')
        .or(`and(requester_id.eq.${user.id},addressee_id.eq.${id}),and(requester_id.eq.${id},addressee_id.eq.${user.id})`),
    ])
    setIsPremium(ownProfile?.is_premium ?? false)

    const accepted = (rows ?? []).find((r) => r.status === 'accepted')
    if (accepted) {
      setFriendStatus('friends')
      setFriendshipId(accepted.id)
      return
    }
    const received = (rows ?? []).find((r) => r.status === 'pending' && r.addressee_id === user.id)
    if (received) {
      setFriendStatus('received')
      setFriendshipId(received.id)
      return
    }
    const sent = (rows ?? []).find((r) => r.status === 'pending' && r.requester_id === user.id)
    if (sent) {
      setFriendStatus('sent')
      setFriendshipId(sent.id)
      return
    }
    setFriendStatus('none')
    setFriendshipId(null)
  }

  useEffect(() => {
    loadFriendStatus()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, id])

  async function sendRequest() {
    if (!user || !id) return
    setFriendBusy(true)
    setFriendError(null)
    const { error } = await supabase.from('friendships').insert({ requester_id: user.id, addressee_id: id })
    if (error) {
      setFriendError(
        isPremium
          ? "Couldn't send that request — try again."
          : 'Sending friend requests requires GaelGrounds Premium — visit the Premium page to upgrade.',
      )
    } else {
      await loadFriendStatus()
    }
    setFriendBusy(false)
  }

  async function respond(accept: boolean) {
    if (!friendshipId) return
    setFriendBusy(true)
    if (accept) {
      await supabase.from('friendships').update({ status: 'accepted' }).eq('id', friendshipId)
    } else {
      await supabase.from('friendships').delete().eq('id', friendshipId)
    }
    await loadFriendStatus()
    setFriendBusy(false)
  }

  async function removeFriendship() {
    if (!friendshipId) return
    setFriendBusy(true)
    await supabase.from('friendships').delete().eq('id', friendshipId)
    await loadFriendStatus()
    setFriendBusy(false)
  }

  useEffect(() => {
    if (!id) return
    let cancelled = false

    async function load() {
      const [{ data: fetchedProfile }, { data: visits }, { data: attendance }, { data: userAchievements }] = await Promise.all([
        supabase.from('user_profiles').select('id, display_name, best_match_id, supported_county_id').eq('id', id!).single(),
        supabase.from('user_visits').select('ground_id').eq('user_id', id!),
        supabase.from('user_match_attendance').select('id').eq('user_id', id!),
        supabase
          .from('user_achievements')
          .select('id, achievement_id, unlocked_at, pinned')
          .eq('user_id', id!)
          .order('unlocked_at', { ascending: false }),
      ])

      if (cancelled) return
      setProfile(fetchedProfile)
      setVisitCount(new Set((visits ?? []).map((v) => v.ground_id)).size)
      setMatchCount((attendance ?? []).length)
      setTotalAchievementCount((userAchievements ?? []).length)

      if (fetchedProfile?.supported_county_id) {
        const { data: countyRow } = await supabase
          .from('counties')
          .select('id, name, primary_colour, secondary_colour')
          .eq('id', fetchedProfile.supported_county_id)
          .single()
        if (!cancelled) setCounty(countyRow)
      } else if (!cancelled) {
        setCounty(null)
      }

      const achievementIds = (userAchievements ?? []).map((a) => a.achievement_id)
      if (achievementIds.length > 0) {
        const { data: defs } = await supabase
          .from('achievement_definitions')
          .select('id, title, description')
          .in('id', achievementIds)
        const defById = new Map((defs ?? []).map((d) => [d.id, d]))
        const rows: AchievementRow[] = (userAchievements ?? [])
          .map((ua) => {
            const d = defById.get(ua.achievement_id)
            if (!d) return null
            return { id: ua.id, title: d.title, description: d.description, unlockedAt: ua.unlocked_at, pinned: ua.pinned }
          })
          .filter((r): r is AchievementRow => r !== null)
        const pinned = rows.filter((r) => r.pinned)
        if (!cancelled) setFavouriteAchievements(pinned.length > 0 ? pinned : rows.slice(0, 4))
      } else if (!cancelled) {
        setFavouriteAchievements([])
      }

      if (fetchedProfile?.best_match_id) {
        const { data: match } = await supabase
          .from('matches')
          .select('id, competition, played_at, home_score, away_score, ground_id, home_county_team_id, away_county_team_id')
          .eq('id', fetchedProfile.best_match_id)
          .single()
        if (match && !cancelled) {
          const teamIds = [match.home_county_team_id, match.away_county_team_id].filter(Boolean) as string[]
          const { data: teams } = teamIds.length
            ? await supabase.from('county_teams').select('id, county_id').in('id', teamIds)
            : { data: [] as { id: string; county_id: string }[] }
          const countyIds = [...new Set((teams ?? []).map((t) => t.county_id))]
          const { data: counties } = countyIds.length
            ? await supabase.from('counties').select('id, name').in('id', countyIds)
            : { data: [] as { id: string; name: string }[] }
          const countyNameById = new Map((counties ?? []).map((c) => [c.id, c.name]))
          const teamById = new Map((teams ?? []).map((t) => [t.id, t]))
          const home = match.home_county_team_id ? teamById.get(match.home_county_team_id) : null
          const away = match.away_county_team_id ? teamById.get(match.away_county_team_id) : null
          let groundName: string | null = null
          if (match.ground_id) {
            const { data: ground } = await supabase.from('grounds').select('name').eq('id', match.ground_id).single()
            groundName = ground?.name ?? null
          }
          if (!cancelled) {
            setBestGame({
              matchId: match.id,
              competition: match.competition,
              playedAt: match.played_at,
              homeName: home ? countyNameById.get(home.county_id) ?? 'TBC' : 'TBC',
              awayName: away ? countyNameById.get(away.county_id) ?? 'TBC' : 'TBC',
              homeScore: match.home_score,
              awayScore: match.away_score,
              groundName,
            })
          }
        }
      } else if (!cancelled) {
        setBestGame(null)
      }

      if (!cancelled) setLoading(false)
    }

    load()
    return () => {
      cancelled = true
    }
  }, [id])

  if (loading) return <div className="page"><p className="muted">Loading…</p></div>
  if (!profile) return <div className="page"><p>Profile not found.</p></div>
  if (id && user && id === user.id) return <Navigate to="/profile" replace />

  return (
    <div className="page">
      <div className="page-header">
        <h1>{profile.display_name ?? 'A fan'}</h1>
        {county ? (
          <p className="muted">
            Supports <Link to={`/counties/${county.id}`}>{county.name}</Link>
          </p>
        ) : (
          <p className="muted">GaelGrounds member</p>
        )}
      </div>

      <div className="friend-action-row">
        {friendStatus === 'friends' && (
          <>
            <span className="badge badge-visited">✓ Friends</span>
            <button className="btn btn-ghost btn-sm" disabled={friendBusy} onClick={removeFriendship}>
              Remove friend
            </button>
          </>
        )}
        {friendStatus === 'none' && (
          <button className="btn btn-primary btn-sm" disabled={friendBusy} onClick={sendRequest}>
            + Add friend
          </button>
        )}
        {friendStatus === 'sent' && (
          <span className="muted small">Friend request sent</span>
        )}
        {friendStatus === 'received' && (
          <>
            <button className="btn btn-primary btn-sm" disabled={friendBusy} onClick={() => respond(true)}>
              Accept friend request
            </button>
            <button className="btn btn-ghost btn-sm" disabled={friendBusy} onClick={() => respond(false)}>
              Decline
            </button>
          </>
        )}
      </div>
      {friendError && <p className="muted small error-text">{friendError}</p>}

      <section className="stats-row">
        <div className="stat-tile">
          <span className="stat-value">{visitCount}</span>
          <span className="stat-label">Grounds visited</span>
        </div>
        <div className="stat-tile">
          <span className="stat-value">{matchCount}</span>
          <span className="stat-label">Matches attended</span>
        </div>
        <div className="stat-tile">
          <span className="stat-value">{totalAchievementCount}</span>
          <span className="stat-label">Achievements</span>
        </div>
      </section>

      <section>
        <h2>⭐ Best Game Ever</h2>
        {bestGame ? (
          <Link to={`/matches/${bestGame.matchId}`} className="card best-game-card">
            <span className="best-game-label">{bestGame.competition ?? 'Gaelic Games'}</span>
            <strong>
              {bestGame.homeName} {bestGame.homeScore && bestGame.awayScore ? `${bestGame.homeScore} – ${bestGame.awayScore}` : 'v'}{' '}
              {bestGame.awayName}
            </strong>
            <span className="muted small">
              {bestGame.playedAt ? formatMatchDate(bestGame.playedAt) : 'Date unavailable'}
              {bestGame.groundName && ` · ${bestGame.groundName}`}
            </span>
          </Link>
        ) : (
          <p className="muted">Hasn't picked a best game yet.</p>
        )}
      </section>

      {favouriteAchievements.length > 0 && (
        <section>
          <h2>Favourite achievements</h2>
          <div className="card-grid">
            {favouriteAchievements.map((a) => (
              <div key={a.id} className="card achievement-card">
                <h3>🏆 {a.title}</h3>
                <p className="muted small">{a.description}</p>
                <p className="muted small">Unlocked {formatShortDate(a.unlockedAt)}</p>
              </div>
            ))}
          </div>
        </section>
      )}

      <Link to="/friends" className="link">
        ← Back to friends
      </Link>
    </div>
  )
}
