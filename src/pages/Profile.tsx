import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import { formatShortDate, formatMatchDate } from '../lib/format'
import { loadAchievementState, type AchievementState } from '../lib/achievements'

type VisitedGround = { groundId: string; name: string; visitCount: number; lastVisitedAt: string }
type AttendedMatch = { id: string; matchId: string; competition: string | null; played_at: string; homeName: string; awayName: string }

function PremiumBadge({ isPremium, premiumExpiresAt }: { isPremium: boolean; premiumExpiresAt: string | null }) {
  if (isPremium) {
    return (
      <Link to="/premium" className="card best-game-card">
        <strong>⭐ Premium member</strong>
        {premiumExpiresAt && <span className="muted small"> · renews {formatShortDate(premiumExpiresAt)}</span>}
      </Link>
    )
  }
  return (
    <Link to="/premium" className="card best-game-card">
      <strong>Go Premium — €1.99/month</strong>
    </Link>
  )
}

type County = { id: string; name: string }

export default function Profile() {
  const { user, signOut, refreshSupportedCounty } = useAuth()
  const [displayName, setDisplayName] = useState('')
  const [savedName, setSavedName] = useState('')
  const [counties, setCounties] = useState<County[]>([])
  const [supportedCountyId, setSupportedCountyId] = useState('')
  const [savedSupportedCountyId, setSavedSupportedCountyId] = useState('')
  const [savingCounty, setSavingCounty] = useState(false)
  const [grounds, setGrounds] = useState<VisitedGround[]>([])
  const [matches, setMatches] = useState<AttendedMatch[]>([])
  const [achievementState, setAchievementState] = useState<AchievementState | null>(null)
  const [bestMatchId, setBestMatchId] = useState<string | null>(null)
  const [isPremium, setIsPremium] = useState(false)
  const [premiumExpiresAt, setPremiumExpiresAt] = useState<string | null>(null)
  const [leaderboardOptIn, setLeaderboardOptIn] = useState(false)
  const [savingLeaderboardOptIn, setSavingLeaderboardOptIn] = useState(false)
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null)
  const [uploadingAvatar, setUploadingAvatar] = useState(false)
  const [avatarError, setAvatarError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [deleteError, setDeleteError] = useState<string | null>(null)

  useEffect(() => {
    if (!user) return
    let cancelled = false

    async function load() {
      const [{ data: profile }, { data: visits }, { data: attendance }, { data: countyRows }, achievementState] = await Promise.all([
        supabase
          .from('user_profiles')
          .select('display_name, best_match_id, avatar_url, is_premium, premium_expires_at, supported_county_id, leaderboard_opt_in')
          .eq('id', user!.id)
          .single(),
        supabase
          .from('user_visits')
          .select('id, ground_id, visited_at')
          .eq('user_id', user!.id)
          .order('visited_at', { ascending: false }),
        supabase
          .from('user_match_attendance')
          .select('id, match_id, created_at')
          .eq('user_id', user!.id)
          .order('created_at', { ascending: false }),
        supabase.from('counties').select('id, name').order('name'),
        loadAchievementState(user!.id),
      ])

      if (!cancelled) setAchievementState(achievementState)

      if (cancelled) return

      if (profile?.display_name) {
        setDisplayName(profile.display_name)
        setSavedName(profile.display_name)
      }
      setBestMatchId(profile?.best_match_id ?? null)
      setAvatarUrl(profile?.avatar_url ?? null)
      setIsPremium(profile?.is_premium ?? false)
      setPremiumExpiresAt(profile?.premium_expires_at ?? null)
      setLeaderboardOptIn(profile?.leaderboard_opt_in ?? false)
      setCounties(countyRows ?? [])
      setSupportedCountyId(profile?.supported_county_id ?? '')
      setSavedSupportedCountyId(profile?.supported_county_id ?? '')

      const groundIds = [...new Set((visits ?? []).map((v) => v.ground_id))]
      const { data: groundRows } = groundIds.length
        ? await supabase.from('grounds').select('id, name').in('id', groundIds)
        : { data: [] as any[] }
      const groundNameById = new Map((groundRows ?? []).map((g) => [g.id, g.name]))
      if (!cancelled) {
        const visitsByGround = new Map<string, { count: number; lastVisitedAt: string }>()
        for (const v of visits ?? []) {
          const existing = visitsByGround.get(v.ground_id)
          if (existing) {
            existing.count += 1
            if (v.visited_at > existing.lastVisitedAt) existing.lastVisitedAt = v.visited_at
          } else {
            visitsByGround.set(v.ground_id, { count: 1, lastVisitedAt: v.visited_at })
          }
        }
        setGrounds(
          [...visitsByGround.entries()]
            .map(([groundId, { count, lastVisitedAt }]) => ({
              groundId,
              name: groundNameById.get(groundId) ?? 'Unknown ground',
              visitCount: count,
              lastVisitedAt,
            }))
            .sort((a, b) => b.lastVisitedAt.localeCompare(a.lastVisitedAt)),
        )
      }

      const matchIds = [...new Set((attendance ?? []).map((a) => a.match_id))]
      if (matchIds.length > 0) {
        const { data: matchRows } = await supabase
          .from('matches')
          .select('id, competition, played_at, home_county_team_id, away_county_team_id')
          .in('id', matchIds)
        const teamIds = [
          ...new Set((matchRows ?? []).flatMap((m) => [m.home_county_team_id, m.away_county_team_id].filter(Boolean))),
        ] as string[]
        const { data: teams } = teamIds.length
          ? await supabase.from('county_teams').select('id, county_id').in('id', teamIds)
          : { data: [] as any[] }
        const countyIds = [...new Set((teams ?? []).map((t) => t.county_id))]
        const { data: counties } = countyIds.length
          ? await supabase.from('counties').select('id, name').in('id', countyIds)
          : { data: [] as any[] }
        const countyNameById = new Map((counties ?? []).map((c) => [c.id, c.name]))
        const teamById = new Map((teams ?? []).map((t) => [t.id, t]))
        const matchById = new Map((matchRows ?? []).map((m) => [m.id, m]))

        if (!cancelled) {
          setMatches(
            (attendance ?? []).map((a) => {
              const m = matchById.get(a.match_id)
              const home = m?.home_county_team_id ? teamById.get(m.home_county_team_id) : null
              const away = m?.away_county_team_id ? teamById.get(m.away_county_team_id) : null
              return {
                id: a.id,
                matchId: a.match_id,
                competition: m?.competition ?? null,
                played_at: m?.played_at ?? a.created_at,
                homeName: home ? countyNameById.get(home.county_id) ?? 'TBC' : 'TBC',
                awayName: away ? countyNameById.get(away.county_id) ?? 'TBC' : 'TBC',
              }
            }),
          )
        }
      }

      if (!cancelled) setLoading(false)
    }

    load()
    return () => {
      cancelled = true
    }
  }, [user])

  async function saveDisplayName() {
    if (!user) return
    setSaving(true)
    await supabase.from('user_profiles').update({ display_name: displayName.trim() }).eq('id', user.id)
    setSavedName(displayName.trim())
    setSaving(false)
  }

  async function saveSupportedCounty() {
    if (!user || !supportedCountyId) return
    setSavingCounty(true)
    const { error } = await supabase.from('user_profiles').update({ supported_county_id: supportedCountyId }).eq('id', user.id)
    if (!error) {
      setSavedSupportedCountyId(supportedCountyId)
      await refreshSupportedCounty()
    }
    setSavingCounty(false)
  }

  async function uploadAvatar(file: File) {
    if (!user) return
    setUploadingAvatar(true)
    setAvatarError(null)
    try {
      const ext = file.type === 'image/png' ? 'png' : 'jpg'
      const path = `${user.id}/${crypto.randomUUID()}.${ext}`
      const { error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(path, file, { contentType: file.type })
      if (uploadError) throw uploadError

      const { data: publicUrlData } = supabase.storage.from('avatars').getPublicUrl(path)
      const { error: updateError } = await supabase
        .from('user_profiles')
        .update({ avatar_url: publicUrlData.publicUrl })
        .eq('id', user.id)
      if (updateError) throw updateError

      setAvatarUrl(publicUrlData.publicUrl)
    } catch {
      setAvatarError("Couldn't upload that photo — try again.")
    } finally {
      setUploadingAvatar(false)
    }
  }

  const unlockedAchievements = useMemo(() => {
    if (!achievementState) return []
    return achievementState.defs
      .filter((d) => achievementState.unlockedByDefId.has(d.id))
      .map((d) => ({ def: d, row: achievementState.unlockedByDefId.get(d.id)! }))
      .sort((a, b) => b.row.unlocked_at.localeCompare(a.row.unlocked_at))
  }, [achievementState])

  const lockedAchievementCount = achievementState ? achievementState.defs.length - unlockedAchievements.length : 0

  // Up to 4 starred (pinned) achievements, falling back to the 4 most
  // recently unlocked when nothing is pinned yet -- matches
  // ProfileView.swift's homeScreenAchievements.
  const homeScreenAchievements = useMemo(() => {
    const pinned = unlockedAchievements.filter((a) => a.row.pinned)
    return pinned.length > 0 ? pinned : unlockedAchievements.slice(0, 4)
  }, [unlockedAchievements])

  // App Store guideline 5.1.2: premium status alone isn't consent to publish
  // someone's name/stats -- Leaderboard.tsx only ever shows profiles with
  // this explicitly set, off by default. Matches ProfileView.swift.
  async function setLeaderboardOptInValue(newValue: boolean) {
    if (!user) return
    const previous = leaderboardOptIn
    setLeaderboardOptIn(newValue)
    setSavingLeaderboardOptIn(true)
    const { error } = await supabase.from('user_profiles').update({ leaderboard_opt_in: newValue }).eq('id', user.id)
    if (error) setLeaderboardOptIn(previous)
    setSavingLeaderboardOptIn(false)
  }

  async function toggleBestGame(matchId: string) {
    const newValue = bestMatchId === matchId ? null : matchId
    setBestMatchId(newValue)
    if (!user) return
    const { error } = await supabase.from('user_profiles').update({ best_match_id: newValue }).eq('id', user.id)
    if (error) {
      setBestMatchId(bestMatchId)
    }
  }

  async function deleteAccount() {
    const confirmed = window.confirm(
      "This permanently deletes your account and all your data — check-ins, grounds visited, achievements and friends. This can't be undone. Delete your account?",
    )
    if (!confirmed) return

    setDeleting(true)
    setDeleteError(null)
    try {
      const { error } = await supabase.functions.invoke('delete-account')
      if (error) throw error
      await signOut()
    } catch {
      setDeleteError("Couldn't delete your account — try again.")
      setDeleting(false)
    }
  }

  if (!user) return null

  return (
    <div className="page">
      <div className="page-header">
        <h1>{savedName || 'Your profile'}</h1>
        <p className="muted">{user.email}</p>
      </div>

      <label className="avatar-upload card">
        {avatarUrl ? (
          <img src={avatarUrl} alt="" className="avatar-preview" />
        ) : (
          <span className="avatar-placeholder">👤</span>
        )}
        <span>{uploadingAvatar ? 'Uploading…' : avatarUrl ? 'Change profile photo' : 'Add profile photo'}</span>
        <input
          type="file"
          accept="image/jpeg,image/png"
          hidden
          disabled={uploadingAvatar}
          onChange={(e) => {
            const file = e.target.files?.[0]
            if (file) uploadAvatar(file)
            e.target.value = ''
          }}
        />
      </label>
      {avatarError && <p className="muted small error-text">{avatarError}</p>}

      <section className="profile-name-editor">
        <label>
          Display name
          <input value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder="Your name" />
        </label>
        <button className="btn btn-outline" disabled={saving || displayName.trim() === savedName} onClick={saveDisplayName}>
          {saving ? 'Saving…' : 'Save'}
        </button>
      </section>

      <section className="profile-name-editor">
        <label>
          Supported county
          <select value={supportedCountyId} onChange={(e) => setSupportedCountyId(e.target.value)}>
            <option value="">Select your county</option>
            {counties.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </label>
        <button
          className="btn btn-outline"
          disabled={savingCounty || !supportedCountyId || supportedCountyId === savedSupportedCountyId}
          onClick={saveSupportedCounty}
        >
          {savingCounty ? 'Saving…' : 'Save'}
        </button>
      </section>

      <section className="stats-row">
        <div className="stat-tile">
          <span className="stat-value">{grounds.length}</span>
          <span className="stat-label">Grounds visited</span>
        </div>
        <div className="stat-tile">
          <span className="stat-value">{matches.length}</span>
          <span className="stat-label">Matches attended</span>
        </div>
        <div className="stat-tile">
          <span className="stat-value">{unlockedAchievements.length}</span>
          <span className="stat-label">Achievements</span>
        </div>
      </section>

      <PremiumBadge isPremium={isPremium} premiumExpiresAt={premiumExpiresAt} />

      {isPremium && (
        <label className="card checkbox-label leaderboard-opt-in">
          <input
            type="checkbox"
            checked={leaderboardOptIn}
            disabled={savingLeaderboardOptIn}
            onChange={(e) => setLeaderboardOptInValue(e.target.checked)}
          />
          <div>
            <strong>Appear on the Leaderboard</strong>
            <p className="muted small">
              Your display name and match/ground stats will be visible to every other GaelGrounds user. Off by
              default — you choose to turn this on.
            </p>
          </div>
        </label>
      )}

      <Link to="/friends" className="card best-game-card friends-link">
        <strong>👥 Friends</strong>
      </Link>

      {loading ? (
        <p className="muted">Loading your history…</p>
      ) : (
        <>
          {bestMatchId &&
            (() => {
              const best = matches.find((m) => m.matchId === bestMatchId)
              return best ? (
                <Link to={`/matches/${best.matchId}`} className="card best-game-card">
                  <span className="best-game-label">⭐ Best Game Ever</span>
                  <strong>
                    {best.homeName} v {best.awayName}
                  </strong>
                </Link>
              ) : null
            })()}

          {(unlockedAchievements.length > 0 || lockedAchievementCount > 0) && (
            <Link to="/achievements" className="card achievements-preview-card">
              <div className="achievements-preview-header">
                <h2>Achievements</h2>
                <span className="muted small">
                  {unlockedAchievements.length} of {unlockedAchievements.length + lockedAchievementCount} →
                </span>
              </div>
              <div className="card-grid">
                {homeScreenAchievements.map(({ def, row }) => (
                  <div key={def.id} className="achievements-preview-item">
                    <h3>🏆 {def.title}</h3>
                    <p className="muted small">{def.description}</p>
                    {row.pinned && <span className="achievements-preview-star">★</span>}
                  </div>
                ))}
              </div>
            </Link>
          )}

          <section>
            <h2>Matches attended</h2>
            {matches.length === 0 ? (
              <p className="muted">
                No matches logged yet. <Link to="/matches">Find a match to check in to →</Link>
              </p>
            ) : (
              <ul className="history-list">
                {matches.map((m) => (
                  <li key={m.id} className="history-list-item">
                    <Link to={`/matches/${m.matchId}`}>
                      <strong>
                        {m.homeName} v {m.awayName}
                      </strong>
                      <span className="muted small">
                        {m.competition ?? 'Gaelic Games'} · {formatMatchDate(m.played_at)}
                      </span>
                    </Link>
                    <button
                      className="star-toggle"
                      onClick={() => toggleBestGame(m.matchId)}
                      aria-label={bestMatchId === m.matchId ? 'Remove as best game ever' : 'Mark as best game ever'}
                    >
                      {bestMatchId === m.matchId ? '★' : '☆'}
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section>
            <h2>Grounds visited</h2>
            {grounds.length === 0 ? (
              <p className="muted">
                No grounds logged yet. <Link to="/grounds">Browse grounds to check in →</Link>
              </p>
            ) : (
              <ul className="history-list">
                {grounds.map((g) => (
                  <li key={g.groundId} className="history-list-item">
                    <Link to={`/grounds/${g.groundId}`}>
                      <strong>{g.name}</strong>
                      <span className="muted small">
                        {g.visitCount} {g.visitCount === 1 ? 'visit' : 'visits'}
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </>
      )}

      <button className="btn btn-ghost" onClick={signOut}>
        Sign out
      </button>

      <button className="btn btn-ghost delete-account-btn" onClick={deleteAccount} disabled={deleting}>
        {deleting ? 'Deleting…' : 'Delete Account'}
      </button>
      {deleteError && <p className="muted small error-text">{deleteError}</p>}
    </div>
  )
}
