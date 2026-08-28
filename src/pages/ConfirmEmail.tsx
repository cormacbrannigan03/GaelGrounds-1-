import { useEffect, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'

// Landed on straight after a successful sign-up, or after a sign-in attempt
// comes back with error.code === 'email_not_confirmed' -- a real, separate
// page (not just a banner on the sign-in form) so there's exactly one clear
// next step. The email itself is a query param rather than router state so
// it survives a refresh/reopen instead of only working immediately after
// navigating here.
export default function ConfirmEmail() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const email = searchParams.get('email')
  const [resendStatus, setResendStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle')

  useEffect(() => {
    if (!email) navigate('/auth', { replace: true })
  }, [email, navigate])

  if (!email) return null

  async function resendConfirmationEmail() {
    setResendStatus('sending')
    const { error } = await supabase.auth.resend({
      type: 'signup',
      email: email!,
      options: { emailRedirectTo: `${window.location.origin}/` },
    })
    setResendStatus(error ? 'error' : 'sent')
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <h1>Confirm your email</h1>
        <div className="confirm-email-panel">
          <p className="form-info">
            We've sent a confirmation link to <strong>{email}</strong>. Open it on this device and you'll be signed
            in automatically — no need to come back here.
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
          <Link to="/auth" className="btn btn-ghost btn-sm">
            Back to sign in
          </Link>
        </div>
      </div>
    </div>
  )
}
