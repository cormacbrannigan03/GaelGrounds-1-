import { useEffect, useState, useCallback } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import { useAchievements } from '../hooks/useAchievements'
import { canLogAnotherMatch, isDateAllowedForFreeTier } from '../lib/matchLimits'
import type { AchievementDefinition } from '../lib/achievements'
import AchievementUnlockedModal from './AchievementUnlockedModal'

type Attendee = {
  id: string
  user_id: string
  created_at: string
  display_name: string | null
}

export default function CheckInPanel({
  matchId,
  isPast = false,
  matchPlayedAt = null,
}: {
  matchId: string
  isPast?: boolean
  matchPlayedAt?: string | null
}) {
  const { user } = useAuth()
  const { evaluate } = useAchievements(user?.id)
  const [attendees, setAttendees] = useState<Attendee[]>([])
  const [myAttendanceId, setMyAttendanceId] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [unlockedAchievements, setUnlockedAchievements] = useState<AchievementDefinition[] | null>(null)
  const [checkInError, setCheckInError] = useState<string | null>(null)
  // Free-tier gating is really enforced server-side (RLS), this is just to
  // show an upgrade prompt proactively instead of a bare failed check-in --
  // matches MatchService.canLogAnotherMatch/isDateAllowedForFreeTier, used
  // by MatchesView.swift's "Add Match" flow and equally applicable here
  // since the same RLS policy also gates user_match_attendance inserts.
  const [blocked, setBlocked] = useState(false)

  useEffect(() => {
    if (!user || myAttendanceId) {
      setBlocked(false)
      return
    }
    let cancelled = false
    async function checkGate() {
      const { data: profile } = await supabase.from('user_profiles').select('is_premium').eq('id', user!.id).single()
      const isPremium = profile?.is_premium ?? false
      if (!isDateAllowedForFreeTier(matchPlayedAt) && !isPremium) {
        if (!cancelled) setBlocked(true)
        return
      }
      const allowed = await canLogAnotherMatch(user!.id, isPremium)
      if (!cancelled) setBlocked(!allowed)
    }
    checkGate()
    return () => {
      cancelled = true
    }
  }, [user, myAttendanceId, matchPlayedAt])

  const loadAttendees = useCallback(async () => {
    if (!user) {
      setAttendees([])
      setMyAttendanceId(null)
      return
    }

    const { data: rows } = await supabase
      .from('user_match_attendance')
      .select('id, user_id, created_at')
      .eq('match_id', matchId)
      .order('created_at', { ascending: false })

    if (!rows) {
      setAttendees([])
      return
    }

    const userIds = rows.map((r) => r.user_id)
    const { data: profiles } = userIds.length
      ? await supabase.from('user_profiles').select('id, display_name').in('id', userIds)
      : { data: [] }

    const nameById = new Map((profiles ?? []).map((p) => [p.id, p.display_name]))
    setAttendees(rows.map((r) => ({ ...r, display_name: nameById.get(r.user_id) ?? null })))
    setMyAttendanceId(rows.find((r) => r.user_id === user?.id)?.id ?? null)
  }, [matchId, user?.id])

  useEffect(() => {
    if (!user) {
      setAttendees([])
      setMyAttendanceId(null)
      setLoading(false)
      return
    }

    setLoading(true)
    loadAttendees().finally(() => setLoading(false))

    const channel = supabase
      .channel(`match-attendance-${matchId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'user_match_attendance', filter: `match_id=eq.${matchId}` },
        () => {
          loadAttendees()
        },
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [matchId, loadAttendees, user])

  async function handleCheckIn() {
    if (!user) return
    setBusy(true)
    setCheckInError(null)
    const { error } = await supabase.from('user_match_attendance').insert({ match_id: matchId, user_id: user.id })
    // Don't wait on the realtime echo to reflect this -- refresh directly,
    // both on success and on a 409 (a stray double-click, or state that was
    // already stale before this click landed; either way the honest fix is
    // to reload the real row rather than leave the button looking broken).
    await loadAttendees()
    if (!error) {
      const newlyUnlocked = await evaluate()
      if (newlyUnlocked.length > 0) setUnlockedAchievements(newlyUnlocked)
    } else if (blocked) {
      // The client-side gate above already flagged this as free-tier-
      // blocked before the click landed, so RLS rejecting it too is
      // expected and this message is actually true for them.
      setCheckInError("Couldn't check in — this may be past the free plan's limit. Upgrade to Premium for unlimited check-ins.")
    } else {
      // The client-side gate thought this was fine (not free-tier-limited),
      // so blaming Premium/the free plan here would be actively wrong --
      // confirmed by a real case where a Premium account hit this exact
      // branch because of an unrelated database error (a ground-visit
      // bookkeeping trigger hitting an unexpected unique-constraint
      // collision, unrelated to their plan at all). A generic message is
      // the honest one when the real cause isn't the free-tier limit.
      setCheckInError("Couldn't check in — please try again.")
    }
    setBusy(false)
  }

  async function handleCheckOut() {
    if (!myAttendanceId) return
    setBusy(true)
    await supabase.from('user_match_attendance').delete().eq('id', myAttendanceId)
    await loadAttendees()
    // Undoing a check-in can drop a count-based achievement back below its
    // threshold -- evaluate() revokes as well as grants, so this is the
    // only way a stale achievement ever gets cleaned up.
    await evaluate()
    setBusy(false)
  }

  return (
    <div className="checkin-panel">
      <div className="checkin-header">
        <div>
          <h3>{isPast ? 'Who was there' : "Who's here"}</h3>
          <p className="muted">{isPast ? 'Check in any time, even after the final whistle' : 'Updates live as fans check in'}</p>
        </div>
        {user &&
          !loading &&
          (myAttendanceId ? (
            <button className="btn btn-outline" disabled={busy} onClick={handleCheckOut}>
              ✓ {isPast ? 'Logged as attended' : 'Checked in'} — tap to undo
            </button>
          ) : blocked ? (
            <Link to="/premium" className="btn btn-gold btn-sm">
              🔒 Upgrade to log this match
            </Link>
          ) : (
            <button className="btn btn-primary btn-lg" disabled={busy} onClick={handleCheckIn}>
              {isPast ? '🕘 I was there' : '📍 Check in'}
            </button>
          ))}
      </div>

      {blocked && !myAttendanceId && (
        <p className="muted small">
          You've reached the free plan's 10-match limit, or this match is from before 2019 — Premium unlocks unlimited
          check-ins and full history.
        </p>
      )}
      {checkInError && <p className="muted small error-text">{checkInError}</p>}

      {unlockedAchievements && (
        <AchievementUnlockedModal achievements={unlockedAchievements} onClose={() => setUnlockedAchievements(null)} />
      )}

      {loading ? (
        <p className="muted">Loading attendees…</p>
      ) : attendees.length === 0 ? (
        <p className="muted">No one's checked in yet — be the first!</p>
      ) : (
        <ul className="attendee-list">
          {attendees.map((a) => (
            <li key={a.id}>
              <span className="avatar-dot" />
              {a.display_name ?? 'A fan'}
              {a.user_id === user?.id && <span className="you-tag">you</span>}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
