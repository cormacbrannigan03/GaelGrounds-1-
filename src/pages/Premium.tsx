import { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import { formatShortDate } from '../lib/format'

const FEATURES = [
  {
    icon: '📖',
    title: 'Full match history',
    desc: 'See every game you have ever checked into, not just the last few.',
  },
  {
    icon: '🕰️',
    title: 'Games before 2019',
    desc: 'Log historic matches and build out your complete GAA story.',
  },
  {
    icon: '🤝',
    title: 'Friend requests',
    desc: 'Connect with other supporters and see who is going where.',
  },
  {
    icon: '🏆',
    title: 'Leaderboard',
    desc: 'Opt in from your Profile and see how you rank against other fans.',
  },
]

const COMPARE_ROWS: { label: string; free: boolean; premium: boolean }[] = [
  { label: 'Check in at matches & grounds', free: true, premium: true },
  { label: 'Achievements & badges', free: true, premium: true },
  { label: 'Recent match history', free: true, premium: true },
  { label: 'Full match history, back to day one', free: false, premium: true },
  { label: 'Log games from before 2019', free: false, premium: true },
  { label: 'Send & accept friend requests', free: false, premium: true },
  { label: 'Appear on the Leaderboard', free: false, premium: true },
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
    <div className="page premium-page">
      <div className="premium-hero">
        <span className="premium-eyebrow">★ GaelGrounds Premium</span>
        <h1>Every game. Every county story. All in your pocket.</h1>
        <p className="lede">
          Unlock your full GAA history, connect with fellow supporters, and climb the leaderboard — on web, iOS and
          Android, from one account.
        </p>
      </div>

      {checkoutResult === 'success' && (
        <p className="card muted small premium-banner">
          Payment received — your account is being upgraded. This can take a few seconds; refresh this page if
          Premium doesn't show as active yet.
        </p>
      )}
      {checkoutResult === 'cancelled' && (
        <p className="card muted small premium-banner">Checkout cancelled — no charge was made.</p>
      )}

      <div className="premium-price-card">
        <div className="premium-price-glow" aria-hidden="true" />
        {!user ? (
          <>
            <p className="premium-price-eyebrow">Premium</p>
            <p className="premium-price">
              €1.99<span>/month</span>
            </p>
            <p className="premium-cancel-note">Cancel any time · No commitment</p>
            <Link to="/auth" className="btn btn-gold btn-lg btn-block">
              Sign in to subscribe
            </Link>
          </>
        ) : loading ? (
          <p className="premium-loading">Loading your Premium status…</p>
        ) : isPremium ? (
          <>
            <p className="premium-price-eyebrow">✓ You're Premium</p>
            <p className="premium-price premium-price-small">Thanks for supporting GaelGrounds</p>
            {premiumExpiresAt && <p className="premium-cancel-note">Renews {formatShortDate(premiumExpiresAt)}</p>}
            <button className="btn btn-outline-light btn-lg btn-block" onClick={openPortal} disabled={managing}>
              {managing ? 'Opening…' : 'Manage subscription'}
            </button>
          </>
        ) : (
          <>
            <p className="premium-price-eyebrow">Premium</p>
            <p className="premium-price">
              €1.99<span>/month</span>
            </p>
            <p className="premium-cancel-note">Cancel any time · No commitment</p>
            <button className="btn btn-gold btn-lg btn-block" onClick={startCheckout} disabled={starting}>
              {starting ? 'Starting checkout…' : 'Subscribe — €1.99/month'}
            </button>
          </>
        )}
      </div>

      {error && <p className="muted small error-text premium-error">{error}</p>}

      <div className="premium-feature-grid">
        {FEATURES.map((f) => (
          <div key={f.title} className="premium-feature-card">
            <span className="premium-feature-icon">{f.icon}</span>
            <h3>{f.title}</h3>
            <p>{f.desc}</p>
          </div>
        ))}
      </div>

      <h2 className="premium-compare-heading">Free vs Premium</h2>
      <div className="premium-compare-wrap">
        <table className="premium-compare">
          <thead>
            <tr>
              <th></th>
              <th>Free</th>
              <th className="premium-col">Premium</th>
            </tr>
          </thead>
          <tbody>
            {COMPARE_ROWS.map((row) => (
              <tr key={row.label}>
                <td>{row.label}</td>
                <td>{row.free ? <span className="yes">✓</span> : <span className="no">—</span>}</td>
                <td>{row.premium ? <span className="yes">✓</span> : <span className="no">—</span>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="premium-trust">
        <span>🔒 Secure checkout via Stripe</span>
        <span>🔄 Cancel anytime, no questions asked</span>
        <span>📱 One account — web, iOS &amp; Android</span>
      </div>
    </div>
  )
}
