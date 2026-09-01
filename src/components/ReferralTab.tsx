import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'

type ReferredUser = { id: string; display_name: string | null; qualified: boolean }

const GOAL = 3

export default function ReferralTab({ userId }: { userId: string }) {
  const [code, setCode] = useState<string | null>(null)
  const [monthsGranted, setMonthsGranted] = useState(0)
  const [referred, setReferred] = useState<ReferredUser[]>([])
  const [loading, setLoading] = useState(true)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    let cancelled = false

    async function load() {
      const [{ data: profile }, { data: referredProfiles }] = await Promise.all([
        supabase.from('user_profiles').select('referral_code, referral_months_granted').eq('id', userId).single(),
        supabase.from('user_profiles').select('id, display_name').eq('referred_by_user_id', userId),
      ])
      if (cancelled) return

      setCode(profile?.referral_code ?? null)
      setMonthsGranted(profile?.referral_months_granted ?? 0)

      const referredIds = (referredProfiles ?? []).map((p) => p.id)
      const { data: attendance } = referredIds.length
        ? await supabase.from('user_match_attendance').select('user_id').in('user_id', referredIds)
        : { data: [] as { user_id: string }[] }
      const qualifiedIds = new Set((attendance ?? []).map((a) => a.user_id))

      if (!cancelled) {
        setReferred(
          (referredProfiles ?? []).map((p) => ({
            id: p.id,
            display_name: p.display_name,
            qualified: qualifiedIds.has(p.id),
          })),
        )
        setLoading(false)
      }
    }

    load()
    return () => {
      cancelled = true
    }
  }, [userId])

  if (loading) return <p className="muted">Loading your referral code…</p>
  if (!code) return <p className="muted">Couldn't load your referral code — try again shortly.</p>

  const link = `${window.location.origin}/auth?ref=${code}`
  const qualifiedCount = referred.filter((r) => r.qualified).length
  const towardNext = qualifiedCount % GOAL
  const remaining = GOAL - towardNext === GOAL ? 0 : GOAL - towardNext

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(link)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // Clipboard access can be denied (permissions, insecure context) --
      // the link is still shown and selectable, so this is a soft failure.
    }
  }

  return (
    <div className="referral-tab">
      <section className="card referral-code-card">
        <p className="muted small">Your referral code</p>
        <p className="referral-code">{code}</p>
        <div className="referral-link-row">
          <input readOnly value={link} onFocus={(e) => e.target.select()} />
          <button className="btn btn-primary btn-sm" onClick={copyLink}>
            {copied ? 'Copied!' : 'Copy link'}
          </button>
        </div>
      </section>

      <section className="card referral-progress-card">
        <p>
          <strong>{qualifiedCount}</strong> friend{qualifiedCount === 1 ? '' : 's'} you referred{' '}
          {qualifiedCount === 1 ? 'has' : 'have'} checked in to a match.
        </p>
        <p className="muted small">
          Every {GOAL} friends who sign up with your link and log a match earns you a free month of Premium.
          {remaining > 0 && ` ${remaining} more to your next free month.`}
        </p>
        {monthsGranted > 0 && (
          <p className="muted small">
            🎉 You've earned {monthsGranted} free month{monthsGranted === 1 ? '' : 's'} of Premium so far.
          </p>
        )}
      </section>

      {referred.length > 0 && (
        <section>
          <h2>Friends you've referred</h2>
          <ul className="history-list">
            {referred.map((r) => (
              <li key={r.id} className="history-list-item">
                <span>{r.display_name ?? 'A fan'}</span>
                <span className={`muted small ${r.qualified ? 'referral-qualified' : ''}`}>
                  {r.qualified ? '✓ Checked in' : 'Waiting on first check-in'}
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  )
}
