import { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import { formatShortDate } from '../lib/format'

const BENEFITS = [
  'Full match history, not just recent games',
  'Log games from before 2019',
  'Send friend requests',
  'Appear on the Leaderboard (you choose to opt in on your Profile)',
]

export default function Premium() {
  const { user } = useAuth()
  const [searchParams] = useSearchParams()
  const checkoutResult = searchParams.get('checkout')

  const [isPremium, setIsPremium] = useState(false)
  const [premiumExpiresAt, setPremiumExpiresAt] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [starting, setStarting] = useState(false)
  const [managing, setManaging] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!user) {
      setLoading(false)
      return
    }
    let cancelled = false
    supabase
      .from('user_profiles')
      .select('is_premium, premium_expires_at')
      .eq('id', user.id)
      .single()
      .then(({ data }) => {
        if (cancelled) return
        setIsPremium(data?.is_premium ?? false)
        setPremiumExpiresAt(data?.premium_expires_at ?? null)
        setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [user])

  async function startCheckout() {
    setStarting(true)
    setError(null)
    try {
      const { data, error: fnError } = await supabase.functions.invoke('create-checkout-session')
      if (fnError) throw fnError
      if (!data?.url) throw new Error('No checkout URL returned')
      window.location.href = data.url
    } catch {
      setError("Couldn't start checkout — try again in a moment.")
      setStarting(false)
    }
  }

  async function openPortal() {
    setManaging(true)
    setError(null)
    try {
      const { data, error: fnError } = await supabase.functions.invoke('create-portal-session')
      if (fnError) throw fnError
      if (!data?.url) throw new Error('No portal URL returned')
      window.location.href = data.url
    } catch {
      setError("Couldn't open the billing portal — try again in a moment.")
      setManaging(false)
    }
  }

  return (
    <div className="page">
      <div className="page-header">
        <h1>GaelGrounds Premium</h1>
        <p className="muted">€1.99/month, cancel any time.</p>
      </div>

      {checkoutResult === 'success' && (
        <p className="card muted small">
          Payment received — your account is being upgraded. This can take a few seconds; refresh this page if
          Premium doesn't show as active yet.
        </p>
      )}
      {checkoutResult === 'cancelled' && <p className="card muted small">Checkout cancelled — no charge was made.</p>}

      <ul className="history-list">
        {BENEFITS.map((benefit) => (
          <li key={benefit}>{benefit}</li>
        ))}
      </ul>

      {error && <p className="muted small error-text">{error}</p>}

      {!user ? (
        <Link to="/auth" className="btn btn-primary">
          Sign in to subscribe
        </Link>
      ) : loading ? (
        <p className="muted">Loading…</p>
      ) : isPremium ? (
        <section className="card">
          <p>
            <strong>You're a Premium member.</strong>
          </p>
          {premiumExpiresAt && (
            <p className="muted small">Renews {formatShortDate(premiumExpiresAt)}</p>
          )}
          <button className="btn btn-outline" onClick={openPortal} disabled={managing}>
            {managing ? 'Opening…' : 'Manage subscription'}
          </button>
        </section>
      ) : (
        <button className="btn btn-primary" onClick={startCheckout} disabled={starting}>
          {starting ? 'Starting checkout…' : 'Subscribe — €1.99/month'}
        </button>
      )}

      <p className="muted small">
        One subscription covers Premium on the website, iOS and Android — the same account, everywhere.
      </p>
    </div>
  )
}
