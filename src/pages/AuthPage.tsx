import { useEffect, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { supabase, withAuthTimeout, clearStaleSession } from '../lib/supabaseClient'

type County = { id: string; name: string }

export default function AuthPage() {
  const { signInWithPassword, signUp, sendPasswordReset, session } = useAuth()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  // Seeded from a shared link's ?ref= param, but also editable directly --
  // not everyone shares the link, some just tell a friend the code.
  const [referralCode, setReferralCode] = useState(() => searchParams.get('ref')?.trim() ?? '')
  // A shared referral link should land straight on the sign-up form, not
  // sign-in -- the person clicking it doesn't have an account yet.
  const [mode, setMode] = useState<'signin' | 'signup'>(referralCode ? 'signup' : 'signin')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [displayName, setDisplayName] = useState('')
  const [counties, setCounties] = useState<County[]>([])
  const [supportedCountyId, setSupportedCountyId] = useState('')
  const [confirmedAge16, setConfirmedAge16] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [forgotBusy, setForgotBusy] = useState(false)
  const [forgotMessage, setForgotMessage] = useState<string | null>(null)

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
          : signUp(email, password, displayName, supportedCountyId, referralCode),
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
      // Distinct from a wrong password (error.code === 'invalid_credentials')
      // -- Supabase tells these apart, so route to the same confirmation
      // page a fresh sign-up lands on rather than showing a generic error
      // that reads like the password was wrong.
      if (mode === 'signin' && 'code' in result && result.code === 'email_not_confirmed') {
        navigate(`/auth/confirm-email?email=${encodeURIComponent(email)}`)
        return
      }
      setError(result.error)
      return
    }

    if (mode === 'signup') {
      navigate(`/auth/confirm-email?email=${encodeURIComponent(email)}`)
    } else {
      navigate('/')
    }
  }

  async function handleForgotPassword() {
    setError(null)
    if (!email) {
      setError('Enter your email above first, then tap "Forgot password?".')
      return
    }
    setForgotBusy(true)
    setForgotMessage(null)
    const { error } = await sendPasswordReset(email)
    setForgotBusy(false)
    // Supabase's own resetPasswordForEmail doesn't reveal whether the
    // address has an account (it "succeeds" either way) -- phrased with
    // "if an account exists" here for the same reason, so this can't be
    // used to check which emails are registered.
    setForgotMessage(error ? "Couldn't send that — please try again." : `If an account exists for ${email}, a reset link is on its way.`)
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <h1>{mode === 'signin' ? 'Welcome back' : 'Create your account'}</h1>
        <p className="muted">Track every ground and match you attend, across all 32 counties.</p>
        {mode === 'signup' && referralCode && (
          <p className="muted small">Referred by a friend — they'll get credit once you check in to a match.</p>
        )}

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

              <label>
                Referral code (optional)
                <input
                  type="text"
                  value={referralCode}
                  onChange={(e) => setReferralCode(e.target.value.toUpperCase())}
                  placeholder="e.g. AB12CD"
                  maxLength={6}
                />
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

          {mode === 'signin' && (
            <button type="button" className="link-button" disabled={forgotBusy} onClick={handleForgotPassword}>
              {forgotBusy ? 'Sending…' : 'Forgot password?'}
            </button>
          )}
          {forgotMessage && <p className="muted small">{forgotMessage}</p>}

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
      </div>
    </div>
  )
}
