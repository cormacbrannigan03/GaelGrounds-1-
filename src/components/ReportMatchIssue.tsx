import { useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'

const ISSUE_TYPES: { key: string; label: string }[] = [
  { key: 'venue', label: 'Venue' },
  { key: 'date', label: 'Date' },
  { key: 'time', label: 'Time' },
  { key: 'score', label: 'Score' },
]

export default function ReportMatchIssue({ matchId }: { matchId: string }) {
  const { user } = useAuth()
  const [open, setOpen] = useState(false)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [details, setDetails] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [submitted, setSubmitted] = useState(false)

  function toggleIssue(key: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(key)) next.delete(key)
      else next.add(key)
      return next
    })
  }

  async function submit() {
    if (!user || selected.size === 0) return
    setSubmitting(true)
    setError(null)
    const { error: insertError } = await supabase.from('match_reports').insert({
      match_id: matchId,
      user_id: user.id,
      issue_types: [...selected],
      details: details.trim() || null,
    })
    setSubmitting(false)
    if (insertError) {
      setError("Couldn't submit that report — try again.")
      return
    }
    setSubmitted(true)
    setOpen(false)
    setSelected(new Set())
    setDetails('')
  }

  if (!user) return null

  if (submitted) {
    return <p className="muted small report-issue-thanks">Thanks — we'll take a look at this match's details.</p>
  }

  if (!open) {
    return (
      <button className="btn btn-ghost btn-sm report-issue-toggle" onClick={() => setOpen(true)}>
        🚩 Report an issue
      </button>
    )
  }

  return (
    <div className="card report-issue-form">
      <h3>Report an issue</h3>
      <p className="muted small">What's wrong? Select everything that looks incorrect.</p>
      <div className="report-issue-options">
        {ISSUE_TYPES.map((issue) => (
          <label key={issue.key} className="checkbox-label report-issue-option">
            <input type="checkbox" checked={selected.has(issue.key)} onChange={() => toggleIssue(issue.key)} />
            <span>{issue.label}</span>
          </label>
        ))}
      </div>
      <label>
        Tell us more (optional)
        <textarea
          value={details}
          onChange={(e) => setDetails(e.target.value)}
          rows={3}
          placeholder="Any extra detail helps — the correct venue, date, time, or score, for example."
        />
      </label>
      {error && <p className="muted small error-text">{error}</p>}
      <div className="report-issue-actions">
        <button className="btn btn-ghost btn-sm" onClick={() => setOpen(false)} disabled={submitting}>
          Cancel
        </button>
        <button className="btn btn-primary btn-sm" onClick={submit} disabled={submitting || selected.size === 0}>
          {submitting ? 'Submitting…' : 'Submit'}
        </button>
      </div>
    </div>
  )
}
