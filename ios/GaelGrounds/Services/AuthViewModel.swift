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

    func signUp(email: String, password: String, displayName: String) async -> String? {
        do {
            let response = try await Supa.client.auth.signUp(email: email, password: password)
            let userId = response.user.id
            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await Supa.client
                .from("user_profiles")
                .insert(UserProfileInsert(id: userId, displayName: name.isEmpty ? nil : name))
                .execute()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func signOut() async {
        try? await Supa.client.auth.signOut()
    }
}
