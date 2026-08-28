import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { supabase, withAuthTimeout, clearStaleSession } from '../lib/supabaseClient'

type County = { id: string; name: string }

export default function AuthPage() {
  const { signInWithPassword, signUp, session } = useAuth()
  const navigate = useNavigate()
  const [mode, setMode] = useState<'signin' | 'signup'>('signin')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [displayName, setDisplayName] = useState('')
  const [counties, setCounties] = useState<County[]>([])
  const [supportedCountyId, setSupportedCountyId] = useState('')
  const [confirmedAge16, setConfirmedAge16] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  // Set right after a successful sign-up, or after a sign-in attempt comes
  // back with error.code === 'email_not_confirmed' -- either way, the same
  // "check your inbox" panel below replaces the plain form so there's one
  // clear next step instead of a form the account can't actually sign into
  // yet, with a resend option in case the confirmation email never arrived.
  const [pendingConfirmationEmail, setPendingConfirmationEmail] = useState<string | null>(null)
  const [resendStatus, setResendStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle')

  useEffect(() => {
    // On a slow connection, signInWithPassword's own request can still be
    // in flight in the background after withAuthTimeout has already given
    // up on it and shown an error below -- Supabase's server-side session
    // creation isn't cancelled by our client-side timeout. If/when that
    // request eventually completes, onAuthStateChange (subscribed in
    // AuthContext) updates `session` here, and without this the user would
    // be left staring at a stale timeout error while actually signed in.
    if (session) navigate('/')
  }, [session, navigate])

  useEffect(() => {
    if (mode !== 'signup' || counties.length > 0) return
    supabase
      .from('counties')
      .select('id, name')
      .order('name')
      .then(({ data }) => setCounties(data ?? []))
  }, [mode, counties.length])

  const canSubmit =
    email.length > 0 &&
    password.length >= 6 &&
    (mode === 'signin' || (supportedCountyId !== '' && confirmedAge16))

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)

    if (mode === 'signup') {
      if (!supportedCountyId) {
        setError('Please select the county you support.')
        return
      }
      if (!confirmedAge16) {
        setError('You must confirm you are 16 or older to create an account.')
        return
      }
    }

    setBusy(true)
    // signInWithPassword/signUp normally resolve with { error } rather than
    // throwing -- but a network hiccup, or a stale/corrupted session token
    // stuck being silently retried in the background, can leave the call
    // hanging or reject it unexpectedly. withAuthTimeout forces it to fail
    // after 8s instead of leaving the button stuck on "Please wait..."
    // forever with no way out short of reloading the page; either way,
    // clearStaleSession() means a poisoned local token can't keep causing
    // the exact same failure on every future attempt.
    let result: { error: string | null; code?: string | null }
    try {
      result = await withAuthTimeout(
        mode === 'signin'
          ? signInWithPassword(email, password)
          : signUp(email, password, displayName, supportedCountyId),
      )
    } catch (err) {
      setBusy(false)
      clearStaleSession()
      setError(
        err instanceof Error && err.message === 'auth-timeout'
          ? "That took too long, so we've reset your session — please try again."
          : "Couldn't reach the server — check your connection and try again.",
      )
      return
    }
    setBusy(false)

    if (result.error) {
      if (mode === 'signin' && 'code' in result && result.code === 'email_not_confirmed') {
        setPendingConfirmationEmail(email)
        setResendStatus('idle')
        return
      }
      setError(result.error)
      return
    }

    if (mode === 'signup') {
      setPendingConfirmationEmail(email)
      setResendStatus('idle')
      setMode('signin')
    } else {
      navigate('/')
    }
  }

  async function resendConfirmationEmail() {
    if (!pendingConfirmationEmail) return
    setResendStatus('sending')
    const { error: resendError } = await supabase.auth.resend({
      type: 'signup',
      email: pendingConfirmationEmail,
    })
    setResendStatus(resendError ? 'error' : 'sent')
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <h1>{mode === 'signin' ? 'Welcome back' : 'Create your account'}</h1>
        <p className="muted">Track every ground and match you attend, across all 32 counties.</p>

        {pendingConfirmationEmail ? (
          <div className="confirm-email-panel">
            <p className="form-info">
              We've sent a confirmation link to <strong>{pendingConfirmationEmail}</strong>. Click it, then come back
              here and sign in.
            </p>
            {resendStatus === 'sent' ? (
              <p className="muted small">Sent again — check your inbox (and spam folder).</p>
            ) : (
              <button
                type="button"
                className="btn btn-outline btn-sm"
                disabled={resendStatus === 'sending'}
                onClick={resendConfirmationEmail}
              >
                {resendStatus === 'sending' ? 'Resending…' : "Didn't get it? Resend email"}
              </button>
            )}
            {resendStatus === 'error' && <p className="muted small error-text">Couldn't resend — try again shortly.</p>}
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={() => {
                setPendingConfirmationEmail(null)
                setResendStatus('idle')
                setMode('signin')
              }}
            >
              Back to sign in
            </button>
          </div>
        ) : (
          <>
            <div className="auth-tabs">
              <button className={mode === 'signin' ? 'active' : ''} onClick={() => setMode('signin')}>
                Sign in
              </button>
              <button className={mode === 'signup' ? 'active' : ''} onClick={() => setMode('signup')}>
                Sign up
              </button>
            </div>

            <form onSubmit={handleSubmit}>
              {mode === 'signup' && (
                <>
                  <label>
                    Display name
                    <input
                      type="text"
                      value={displayName}
                      onChange={(e) => setDisplayName(e.target.value)}
                      placeholder="e.g. Sean O'Brien"
                    />
                  </label>

                  <label>
                    Supported county
                    <select value={supportedCountyId} onChange={(e) => setSupportedCountyId(e.target.value)} required>
                      <option value="">Select your county</option>
                      {counties.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                        </option>
                      ))}
                    </select>
                  </label>
                </>
              )}

              <label>
                Email
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                />
              </label>
              <label>
                Password
                <input
                  type="password"
                  required
                  minLength={6}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                />
              </label>

              {mode === 'signup' && (
                // GDPR Article 6/8: Ireland sets the digital age of consent at
                // 16, the maximum allowed under the regulation. Self-attestation,
                // not ID verification -- matches AuthView.swift's Toggle exactly.
                <label className="checkbox-label">
                  <input type="checkbox" checked={confirmedAge16} onChange={(e) => setConfirmedAge16(e.target.checked)} />
                  <span className="small">I confirm I am 16 years of age or older.</span>
                </label>
              )}

              {error && <p className="form-error">{error}</p>}

              <button type="submit" className="btn btn-primary btn-lg btn-block" disabled={busy || !canSubmit}>
                {busy ? 'Please wait…' : mode === 'signin' ? 'Sign in' : 'Create account'}
              </button>
            </form>
          </>
        )}
      </div>
    </div>
  )
}
