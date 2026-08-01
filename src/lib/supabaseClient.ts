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
