import { useEffect, useState, useCallback } from 'react'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import { useAchievements } from '../hooks/useAchievements'

type Attendee = {
  id: string
  user_id: string
  created_at: string
  display_name: string | null
}

export default function CheckInPanel({ matchId, isPast = false }: { matchId: string; isPast?: boolean }) {
  const { user } = useAuth()
  const { evaluate } = useAchievements(user?.id)
  const [attendees, setAttendees] = useState<Attendee[]>([])
  const [myAttendanceId, setMyAttendanceId] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [unlockedToast, setUnlockedToast] = useState<string[] | null>(null)

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
    const { error } = await supabase.from('user_match_attendance').insert({ match_id: matchId, user_id: user.id })
    // Don't wait on the realtime echo to reflect this -- refresh directly,
    // both on success and on a 409 (a stray double-click, or state that was
    // already stale before this click landed; either way the honest fix is
    // to reload the real row rather than leave the button looking broken).
    await loadAttendees()
    if (!error) {
      const newlyUnlocked = await evaluate()
      if (newlyUnlocked.length > 0) setUnlockedToast(newlyUnlocked)
    }
    setBusy(false)
  }

  async function handleCheckOut() {
    if (!myAttendanceId) return
    setBusy(true)
    await supabase.from('user_match_attendance').delete().eq('id', myAttendanceId)
    await loadAttendees()
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
          ) : (
            <button className="btn btn-primary btn-lg" disabled={busy} onClick={handleCheckIn}>
              {isPast ? '🕘 I was there' : '📍 Check in'}
            </button>
          ))}
      </div>

      {unlockedToast && (
        <div className="toast toast-achievement" onClick={() => setUnlockedToast(null)}>
          🏆 Achievement unlocked: {unlockedToast.join(', ')}
        </div>
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
