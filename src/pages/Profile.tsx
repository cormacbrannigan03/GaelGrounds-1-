import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import { formatShortDate, formatMatchDate } from '../lib/format'

type VisitedGround = { groundId: string; name: string; visitCount: number; lastVisitedAt: string }
type AttendedMatch = { id: string; competition: string | null; played_at: string; homeName: string; awayName: string }
type Achievement = { id: string; title: string; description: string; icon: string | null; unlocked_at: string }

export default function Profile() {
  const { user, signOut } = useAuth()
  const [displayName, setDisplayName] = useState('')
  const [savedName, setSavedName] = useState('')
  const [grounds, setGrounds] = useState<VisitedGround[]>([])
  const [matches, setMatches] = useState<AttendedMatch[]>([])
  const [achievements, setAchievements] = useState<Achievement[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!user) return
    let cancelled = false

    async function load() {
      const [{ data: profile }, { data: visits }, { data: attendance }, { data: userAch }] = await Promise.all([
        supabase.from('user_profiles').select('display_name').eq('id', user!.id).single(),
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
        supabase
          .from('user_achievements')
          .select('id, unlocked_at, achievement_id')
          .eq('user_id', user!.id)
          .order('unlocked_at', { ascending: false }),
      ])

      if (cancelled) return

      if (profile?.display_name) {
        setDisplayName(profile.display_name)
        setSavedName(profile.display_name)
      }

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
                competition: m?.competition ?? null,
                played_at: m?.played_at ?? a.created_at,
                homeName: home ? countyNameById.get(home.county_id) ?? 'TBC' : 'TBC',
                awayName: away ? countyNameById.get(away.county_id) ?? 'TBC' : 'TBC',
              }
            }),
          )
        }
      }

      const achievementIds = (userAch ?? []).map((a) => a.achievement_id)
      if (achievementIds.length > 0) {
        const { data: defs } = await supabase
          .from('achievement_definitions')
          .select('id, title, description, icon')
          .in('id', achievementIds)
        const defById = new Map((defs ?? []).map((d) => [d.id, d]))
        if (!cancelled) {
          setAchievements(
            (userAch ?? []).map((a) => {
              const d = defById.get(a.achievement_id)
              return {
                id: a.id,
                title: d?.title ?? 'Achievement',
                description: d?.description ?? '',
                icon: d?.icon ?? null,
                unlocked_at: a.unlocked_at,
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

  if (!user) return null

  return (
    <div className="page">
      <div className="page-header">
        <h1>{savedName || 'Your profile'}</h1>
        <p className="muted">{user.email}</p>
      </div>

      <section className="profile-name-editor">
        <label>
          Display name
          <input value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder="Your name" />
        </label>
        <button className="btn btn-outline" disabled={saving || displayName.trim() === savedName} onClick={saveDisplayName}>
          {saving ? 'Saving…' : 'Save'}
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
          <span className="stat-value">{achievements.length}</span>
          <span className="stat-label">Achievements</span>
        </div>
      </section>

      {loading ? (
        <p className="muted">Loading your history…</p>
      ) : (
        <>
          {achievements.length > 0 && (
            <section>
              <h2>Achievements</h2>
              <div className="card-grid">
                {achievements.map((a) => (
                  <div key={a.id} className="card achievement-card">
                    <h3>🏆 {a.title}</h3>
                    <p className="muted small">{a.description}</p>
                    <p className="muted small">Unlocked {formatShortDate(a.unlocked_at)}</p>
                  </div>
                ))}
              </div>
            </section>
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
                  <li key={m.id}>
                    <strong>
                      {m.homeName} v {m.awayName}
                    </strong>
                    <span className="muted small">
                      {m.competition ?? 'Gaelic Games'} · {formatMatchDate(m.played_at)}
                    </span>
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
                  <li key={g.groundId}>
                    <strong>{g.name}</strong>
                    <span className="muted small">
                      {g.visitCount} {g.visitCount === 1 ? 'visit' : 'visits'}
                    </span>
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
    </div>
  )
}
