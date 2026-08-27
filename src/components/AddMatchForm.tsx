import { useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'

export default function AddMatchForm({ onAdded, onCancel }: { onAdded: () => void; onCancel: () => void }) {
  const { user } = useAuth()
  const [homeTeam, setHomeTeam] = useState('')
  const [awayTeam, setAwayTeam] = useState('')
  const [competition, setCompetition] = useState('')
  const [round, setRound] = useState('')
  const [venue, setVenue] = useState('')
  const [playedAt, setPlayedAt] = useState('')
  const [homeScore, setHomeScore] = useState('')
  const [awayScore, setAwayScore] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const canSubmit = homeTeam.trim() !== '' && awayTeam.trim() !== '' && playedAt !== ''

  async function submit() {
    if (!user || !canSubmit) return
    setSubmitting(true)
    setError(null)
    const { error: insertError } = await supabase.from('user_personal_matches').insert({
      user_id: user.id,
      home_team: homeTeam.trim(),
      away_team: awayTeam.trim(),
      competition: competition.trim() || null,
      round: round.trim() || null,
      venue: venue.trim() || null,
      played_at: new Date(playedAt).toISOString(),
      home_score: homeScore.trim() || null,
      away_score: awayScore.trim() || null,
    })
    setSubmitting(false)
    if (insertError) {
      setError("Couldn't add that match — matches before 2019 need Premium, and free accounts are capped at 10 logged matches total.")
      return
    }
    onAdded()
  }

  return (
    <div className="card add-match-form">
      <h3>Add a match</h3>
      <p className="muted small">For games not in our official results — you attended, but we don't have the record.</p>

      <div className="add-match-grid">
        <label>
          Home team
          <input type="text" value={homeTeam} onChange={(e) => setHomeTeam(e.target.value)} placeholder="e.g. Kerry" />
        </label>
        <label>
          Away team
          <input type="text" value={awayTeam} onChange={(e) => setAwayTeam(e.target.value)} placeholder="e.g. Dublin" />
        </label>
        <label>
          Competition (optional)
          <input type="text" value={competition} onChange={(e) => setCompetition(e.target.value)} placeholder="e.g. Munster SFC" />
        </label>
        <label>
          Round (optional)
          <input type="text" value={round} onChange={(e) => setRound(e.target.value)} placeholder="e.g. Semi Final" />
        </label>
        <label>
          Venue (optional)
          <input type="text" value={venue} onChange={(e) => setVenue(e.target.value)} placeholder="e.g. Fitzgerald Stadium" />
        </label>
        <label>
          Date played
          <input type="date" value={playedAt} onChange={(e) => setPlayedAt(e.target.value)} />
        </label>
        <label>
          Home score (optional)
          <input type="text" value={homeScore} onChange={(e) => setHomeScore(e.target.value)} placeholder="e.g. 1-14" />
        </label>
        <label>
          Away score (optional)
          <input type="text" value={awayScore} onChange={(e) => setAwayScore(e.target.value)} placeholder="e.g. 0-15" />
        </label>
      </div>

      {error && <p className="muted small error-text">{error}</p>}

      <div className="report-issue-actions">
        <button className="btn btn-ghost btn-sm" onClick={onCancel} disabled={submitting}>
          Cancel
        </button>
        <button className="btn btn-primary btn-sm" onClick={submit} disabled={submitting || !canSubmit}>
          {submitting ? 'Adding…' : 'Add match'}
        </button>
      </div>
    </div>
  )
}
