import Combine
import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var session: Session?

    var userId: UUID? { session?.user.id }
    var userEmail: String? { session?.user.email }
    var isSignedIn: Bool { session != nil }

    init() {
        session = Supa.client.auth.currentSession
    }

    func startObserving() async {
        for await (_, newSession) in Supa.client.auth.authStateChanges {
            session = newSession
        }
    }

    func signIn(email: String, password: String) async -> String? {
        do {
            _ = try await Supa.client.auth.signIn(email: email, password: password)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Passes displayName/supportedCountyId as signUp metadata rather than
    /// writing user_profiles directly here. With email confirmation on
    /// (the project's current setting), signUp() returns no active session,
    /// so a follow-up insert from this client would run as the anon role --
    /// which has no grants on user_profiles at all -- and fail outright. The
    /// `handle_new_user()` trigger on auth.users (see
    /// supabase/migrations/20260805001600_create_profile_on_signup_trigger.sql)
    /// creates the profile row server-side instead, using this same
    /// metadata, regardless of whether a session comes back immediately.
    func signUp(
        email: String,
        password: String,
        displayName: String,
        supportedCountyId: UUID,
        referralCode: String? = nil
    ) async -> String? {
        do {
            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            // Sent even when empty -- handle_new_user() on the server only
            // looks up a referrer when this is non-empty, so there's
            // nothing to guard client-side.
            let trimmedCode = referralCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            _ = try await Supa.client.auth.signUp(
                email: email,
                password: password,
                data: [
                    "display_name": .string(name),
                    "supported_county_id": .string(supportedCountyId.uuidString),
                    "referral_code": .string(trimmedCode),
                ]
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func signOut() async {
        try? await Supa.client.auth.signOut()
    }
}
