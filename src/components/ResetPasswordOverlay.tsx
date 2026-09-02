import { useState } from 'react'
import { useAuth } from '../context/AuthContext'

// Shown over whatever page a password-recovery link's redirect lands on --
// rendered at the App root (not a route) since Supabase's PASSWORD_RECOVERY
// event can fire regardless of current path.
export default function ResetPasswordOverlay() {
  const { updatePassword } = useAuth()
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    if (password.length < 6) {
      setError('Password must be at least 6 characters.')
      return
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match.')
      return
    }
    setBusy(true)
    const { error } = await updatePassword(password)
    setBusy(false)
    if (error) setError(error)
  }

  return (
    <div className="achievement-modal-overlay">
      <div className="achievement-modal">
        <h2>Set a new password</h2>
        <p className="muted">Choose a new password for your account.</p>
        <form onSubmit={handleSubmit}>
          <label>
            New password
            <input
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              autoFocus
            />
          </label>
          <label>
            Confirm new password
            <input
              type="password"
              required
              minLength={6}
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="••••••••"
            />
          </label>
          {error && <p className="form-error">{error}</p>}
          <button type="submit" className="btn btn-primary btn-block" disabled={busy}>
            {busy ? 'Saving…' : 'Save new password'}
          </button>
        </form>
      </div>
    </div>
  )
}
