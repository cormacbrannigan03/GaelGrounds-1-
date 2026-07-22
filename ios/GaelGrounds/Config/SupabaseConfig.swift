import Foundation

/// GaelGrounds Supabase project.
///
/// The anon/publishable key below is safe to ship in client code by design —
/// it identifies the project but grants no access on its own. Every table is
/// protected by Row Level Security policies in Postgres, so this key can
/// only ever do what those policies allow (read public fixtures/grounds, or
/// read/write a signed-in user's own check-ins). Never put the
/// `service_role` key here or anywhere in the app bundle.
enum SupabaseConfig {
    static let url = URL(string: "https://wksahsfkldxhusiftosj.supabase.co")!
    static let anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indrc2Foc2ZrbGR4aHVzaWZ0b3NqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3MzM1NzcsImV4cCI6MjEwMDMwOTU3N30.COfinb8AhYy4mBEQkRWkdFRyj5boK4WbmBGRqVYPyKU"
}
