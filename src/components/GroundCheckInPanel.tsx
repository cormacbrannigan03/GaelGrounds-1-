import { useEffect, useState, useCallback } from 'react'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import { useAchievements } from '../hooks/useAchievements'
import { formatShortDate } from '../lib/format'
import type { AchievementDefinition } from '../lib/achievements'
import AchievementUnlockedModal from './AchievementUnlockedModal'

type Visit = {
  id: string
  user_id: string
  visited_at: string
  notes: string | null
  display_name: string | null
}

export default function GroundCheckInPanel({ groundId }: { groundId: string }) {
  const { user } = useAuth()
  const { evaluate } = useAchievements(user?.id)
  const [visits, setVisits] = useState<Visit[]>([])
  const [myVisitId, setMyVisitId] = useState<string | null>(null)
  const [notes, setNotes] = useState('')
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [unlockedAchievements, setUnlockedAchievements] = useState<AchievementDefinition[] | null>(null)
  const [photoUrls, setPhotoUrls] = useState<string[]>([])
  const [myPhotoUrls, setMyPhotoUrls] = useState<string[]>([])
  const [uploadingPhoto, setUploadingPhoto] = useState(false)
  const [photoError, setPhotoError] = useState<string | null>(null)

  const loadVisits = useCallback(async () => {
    if (!user) {
      setVisits([])
      setMyVisitId(null)
      setPhotoUrls([])
      setMyPhotoUrls([])
      return
    }

    const { data: rows } = await supabase
      .from('user_visits')
      .select('id, user_id, visited_at, notes, photo_urls')
      .eq('ground_id', groundId)
      .order('visited_at', { ascending: false })
      .limit(25)

    if (!rows) {
      setVisits([])
      return
    }

    const userIds = [...new Set(rows.map((r) => r.user_id))]
    const { data: profiles } = userIds.length
      ? await supabase.from('user_profiles').select('id, display_name').in('id', userIds)
      : { data: [] }
    const nameById = new Map((profiles ?? []).map((p) => [p.id, p.display_name]))

    setVisits(rows.map((r) => ({ ...r, display_name: nameById.get(r.user_id) ?? null })))
    setMyVisitId(rows.find((r) => r.user_id === user?.id)?.id ?? null)
    setPhotoUrls(rows.flatMap((r) => r.photo_urls ?? []))
    setMyPhotoUrls(rows.find((r) => r.user_id === user?.id)?.photo_urls ?? [])
  }, [groundId, user?.id])

  useEffect(() => {
    if (!user) {
      setVisits([])
      setMyVisitId(null)
      setLoading(false)
      return
    }

    setLoading(true)
    loadVisits().finally(() => setLoading(false))

    const channel = supabase
      .channel(`ground-visits-${groundId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'user_visits', filter: `ground_id=eq.${groundId}` },
        () => loadVisits(),
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [groundId, loadVisits, user])

  async function handleCheckIn() {
    if (!user) return
    setBusy(true)
    const { error } = await supabase
      .from('user_visits')
      .insert({ ground_id: groundId, user_id: user.id, notes: notes.trim() || null })
    // Refresh directly rather than waiting on the realtime echo -- see
    // CheckInPanel.tsx's handleCheckIn for why (button could otherwise get
    // stuck showing the pre-check-in state on a slow/missed realtime event).
    await loadVisits()
    if (!error) {
      setNotes('')
      const newlyUnlocked = await evaluate()
      if (newlyUnlocked.length > 0) setUnlockedAchievements(newlyUnlocked)
    }
    setBusy(false)
  }

  async function handleUndo() {
    if (!myVisitId) return
    setBusy(true)
    await supabase.from('user_visits').delete().eq('id', myVisitId)
    await loadVisits()
    // Same reasoning as CheckInPanel.tsx's handleCheckOut -- evaluate()
    // revokes as well as grants, so undo has to call it too.
    await evaluate()
    setBusy(false)
  }

  async function addPhoto(file: File) {
    if (!user) return
    setUploadingPhoto(true)
    setPhotoError(null)
    try {
      const ext = file.type === 'image/png' ? 'png' : file.type === 'image/webp' ? 'webp' : 'jpg'
      const path = `${user.id}/${groundId}/${crypto.randomUUID()}.${ext}`
      const { error: uploadError } = await supabase.storage
        .from('ground-photos')
        .upload(path, file, { contentType: file.type })
      if (uploadError) throw uploadError

      const { data: publicUrlData } = supabase.storage.from('ground-photos').getPublicUrl(path)
      const url = publicUrlData.publicUrl

      // Photos attach to the uploader's user_visits row for this ground --
      // uploading one without having checked in yet creates that row (with
      // no note), same as GroundPhotoService/addPhoto on iOS.
      if (myVisitId) {
        await supabase.from('user_visits').update({ photo_urls: [...myPhotoUrls, url] }).eq('id', myVisitId)
      } else {
        await supabase.from('user_visits').insert({ ground_id: groundId, user_id: user.id, notes: null, photo_urls: [url] })
      }
      await loadVisits()
    } catch {
      setPhotoError("Upload failed — please try again.")
    } finally {
      setUploadingPhoto(false)
    }
  }

  return (
    <div className="checkin-panel">
      <div className="checkin-header">
        <div>
          <h3>Visitors</h3>
          <p className="muted">Updates live as fans check in</p>
        </div>
      </div>

      {user && !loading && !myVisitId && (
        <div className="checkin-form">
          <input
            type="text"
            placeholder="Add a note (optional) — e.g. 'Here for the Munster final'"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
          />
          <button className="btn btn-primary btn-lg" disabled={busy} onClick={handleCheckIn}>
            📍 Check in here
          </button>
        </div>
      )}
      {user && !loading && myVisitId && (
        <button className="btn btn-outline" disabled={busy} onClick={handleUndo}>
          ✓ Checked in — tap to undo
        </button>
      )}

      {unlockedAchievements && (
        <AchievementUnlockedModal achievements={unlockedAchievements} onClose={() => setUnlockedAchievements(null)} />
      )}

      <div className="ground-photos">
        <div className="ground-photos-header">
          <div>
            <h4>Photos</h4>
            <p className="muted small">Shared by fans who've been here</p>
          </div>
          {user && (
            <label className="btn btn-outline btn-sm ground-photo-upload">
              📷 Add photo
              <input
                type="file"
                accept="image/*"
                hidden
                disabled={uploadingPhoto}
                onChange={(e) => {
                  const file = e.target.files?.[0]
                  e.target.value = ''
                  if (file) addPhoto(file)
                }}
              />
            </label>
          )}
        </div>
        {uploadingPhoto && <p className="muted small">Uploading…</p>}
        {photoError && <p className="muted small error-text">{photoError}</p>}
        {photoUrls.length === 0 ? (
          <p className="muted small">No photos yet — be the first to add one!</p>
        ) : (
          <div className="ground-photos-strip">
            {photoUrls.map((url) => (
              <img key={url} src={url} alt="" className="ground-photo-thumb" loading="lazy" />
            ))}
          </div>
        )}
      </div>

      {loading ? (
        <p className="muted">Loading visitors…</p>
      ) : visits.length === 0 ? (
        <p className="muted">No check-ins yet — be the first!</p>
      ) : (
        <ul className="attendee-list">
          {visits.map((v) => (
            <li key={v.id}>
              <span className="avatar-dot" />
              <span>
                {v.display_name ?? 'A fan'} <span className="muted small">· {formatShortDate(v.visited_at)}</span>
                {v.notes && <div className="muted small">"{v.notes}"</div>}
              </span>
              {v.user_id === user?.id && <span className="you-tag">you</span>}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
