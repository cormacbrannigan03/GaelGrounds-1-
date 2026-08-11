import Foundation
import Supabase

/// Permanently deletes the signed-in user's own account, via the
/// `delete-account` Edge Function (client-side code can never delete an
/// auth user directly -- that requires the service_role key, which must
/// never ship in the app). The function resolves the caller's own id from
/// their JWT server-side, so this can only ever delete the signed-in
/// user's own account.
enum AccountService {
    static func deleteAccount() async throws {
        _ = try await Supa.client.functions.invoke("delete-account")
    }
}
