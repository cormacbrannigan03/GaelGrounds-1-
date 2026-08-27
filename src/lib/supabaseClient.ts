import { createClient } from '@supabase/supabase-js'
import type { Database } from './database.types'

// GaelGrounds Supabase project.
// The anon/publishable key below is safe to ship in client-side code by
// design — it identifies the project but grants no access on its own.
// Every table is protected by Row Level Security policies in Postgres, so
// this key can only ever do what those policies allow (e.g. read public
// fixtures/grounds, but only ever read or write a signed-in user's own
// check-ins). Never put the `service_role` key here or in any frontend code.
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL ?? 'https://wksahsfkldxhusiftosj.supabase.co'
const SUPABASE_ANON_KEY =
  import.meta.env.VITE_SUPABASE_ANON_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indrc2Foc2ZrbGR4aHVzaWZ0b3NqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3MzM1NzcsImV4cCI6MjEwMDMwOTU3N30.COfinb8AhYy4mBEQkRWkdFRyj5boK4WbmBGRqVYPyKU'

export const supabase = createClient<Database>(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
})

const AUTH_TIMEOUT_MS = 8000

/**
 * Forces an auth call to fail after AUTH_TIMEOUT_MS instead of hanging
 * forever. supabase-js's auth methods normally resolve with { error }
 * rather than rejecting, but if the underlying request never completes
 * at all (not erroring, just perpetually pending -- e.g. while silently
 * trying to refresh a stale/corrupted session token in the background),
 * neither a .then() nor a .catch() ever fires without this.
 */
export function withAuthTimeout<T>(promise: Promise<T>, ms = AUTH_TIMEOUT_MS): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('auth-timeout')), ms)
    promise.then(
      (value) => {
        clearTimeout(timer)
        resolve(value)
      },
      (error) => {
        clearTimeout(timer)
        reject(error)
      },
    )
  })
}

/**
 * Wipes any locally-stored Supabase session so a stale/corrupted refresh
 * token can't keep hanging or failing every future auth attempt the same
 * way -- called whenever an auth call times out or throws unexpectedly,
 * so the next sign-in/sign-up starts from a clean slate instead of
 * requiring the user to manually clear their browser's storage.
 */
export function clearStaleSession() {
  try {
    for (const key of Object.keys(localStorage)) {
      if (key.startsWith('sb-') && key.endsWith('-auth-token')) {
        localStorage.removeItem(key)
      }
    }
  } catch {
    // localStorage can be unavailable (strict private-browsing modes) --
    // nothing to clean up in that case, so just move on.
  }
}
