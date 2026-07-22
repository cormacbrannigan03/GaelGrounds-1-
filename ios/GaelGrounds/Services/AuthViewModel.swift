import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true

    var userId: UUID? { session?.user.id }
    var userEmail: String? { session?.user.email }
    var isSignedIn: Bool { session != nil }

    private var authTask: Task<Void, Never>?

    init() {
        authTask = Task { [weak self] in
            guard let self else { return }
            for await (_, newSession) in Supa.client.auth.authStateChanges {
                self.session = newSession
                self.isLoading = false
            }
        }
    }

    deinit {
        authTask?.cancel()
    }

    func signIn(email: String, password: String) async -> String? {
        do {
            _ = try await Supa.client.auth.signInWithPassword(email: email, password: password)
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
