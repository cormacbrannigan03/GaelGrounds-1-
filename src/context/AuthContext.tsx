import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { supabase, withAuthTimeout } from '../lib/supabaseClient'

export type SupportedCounty = {
  id: string
  name: string
  primaryColour: string | null
  secondaryColour: string | null
}

type AuthContextValue = {
  session: Session | null
  user: User | null
  loading: boolean
  supportedCounty: SupportedCounty | null
  refreshSupportedCounty: () => Promise<void>
  signInWithPassword: (email: string, password: string) => Promise<{ error: string | null }>
  signUp: (email: string, password: string, displayName: string, supportedCountyId: string) => Promise<{ error: string | null }>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [supportedCounty, setSupportedCounty] = useState<SupportedCounty | null>(null)

  useEffect(() => {
    // Without the timeout+catch here, a hung or rejected getSession() (a
    // network hiccup, or a stale/corrupted refresh token stuck being
    // silently retried in the background) left `loading` stuck true
    // forever -- every page gated on it (ProtectedRoute, and the
    // auth-dependent bits of every other page) would then be stuck
    // showing its own loading state indefinitely, with no error and no
    // way out short of a page reload.
    //
    // Deliberately does NOT clear local session storage on failure here.
    // getSession() only hits the network at all when the stored access
    // token has expired and needs a background refresh -- and switching
    // networks (e.g. turning off WiFi to fall back to cellular) causes
    // exactly the kind of brief connectivity gap that trips this timeout,
    // even though the stored refresh token is still perfectly valid. An
    // earlier version wiped storage here on any timeout, which actively
    // logged a signed-in user out the moment their network blipped --
    // far worse than the stuck-loading bug it was meant to fix. The
    // underlying getSession() call isn't cancelled by the timeout, so it
    // keeps running and, if the stored token really is valid, its result
    // still lands via the onAuthStateChange subscription below once the
    // network recovers.
    withAuthTimeout(supabase.auth.getSession())
      .then(({ data }) => {
        setSession(data.session)
        setLoading(false)
      })
      .catch(() => {
        setLoading(false)
      })

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession)
    })

    return () => subscription.subscription.unsubscribe()
  }, [])

  const userId = session?.user?.id ?? null

  const loadSupportedCounty = useCallback(async (forUserId: string) => {
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('supported_county_id')
      .eq('id', forUserId)
      .single()

    if (!profile?.supported_county_id) {
      setSupportedCounty(null)
      return
    }

    const { data: county } = await supabase
      .from('counties')
      .select('id, name, primary_colour, secondary_colour')
      .eq('id', profile.supported_county_id)
      .single()

    if (county) {
      setSupportedCounty({
        id: county.id,
        name: county.name,
        primaryColour: county.primary_colour,
        secondaryColour: county.secondary_colour,
      })
    }
  }, [])

  useEffect(() => {
    if (!userId) {
      setSupportedCounty(null)
      return
    }
    loadSupportedCounty(userId)
  }, [userId, loadSupportedCounty])

  async function refreshSupportedCounty() {
    if (userId) await loadSupportedCounty(userId)
  }

  async function signInWithPassword(email: string, password: string) {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    return { error: error?.message ?? null }
  }

  async function signUp(email: string, password: string, displayName: string, supportedCountyId: string) {
    // A profile row is created server-side by a trigger on auth.users (see
    // supabase/migrations/20260805001600_create_profile_on_signup_trigger.sql)
    // reading this metadata -- NOT by inserting into user_profiles directly
    // here. That trigger's own comment documents exactly why: with email
    // confirmation on, signUp() returns no session, so a client-side insert
    // right after it runs as the anon role (which has no grants on
    // user_profiles at all) and fails with "permission denied" on every
    // single signup. Matches AuthViewModel.swift's signUp(), which passes
    // the same two fields the same way.
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          display_name: displayName.trim() || email.split('@')[0],
          supported_county_id: supportedCountyId,
        },
      },
    })
    return { error: error?.message ?? null }
  }

  async function signOut() {
    await supabase.auth.signOut()
  }

  return (
    <AuthContext.Provider
      value={{
        session,
        user: session?.user ?? null,
        loading,
        supportedCounty,
        refreshSupportedCounty,
        signInWithPassword,
        signUp,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
