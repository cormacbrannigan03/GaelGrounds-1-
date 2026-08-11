import Combine
import Foundation
import Supabase

/// Single shared source of truth for the signed-in user's supported county
/// name, used to tint every main tab's background via `.countyBackground(_:)`
/// (Home, Matches, Grounds, Counties, Leaderboard, Profile).
///
/// Previously each of those 5 tabs (Profile derived it locally) fetched this
/// independently via `SupportedCountyService.fetchName` -- two sequential
/// queries, run separately by every tab, only once per tab's lifetime since
/// `.task` doesn't re-run while a tab stays mounted in the background. That's
/// slow to first appear (5x the round trips, none of them running until each
/// tab's own load fires) and goes stale: change your county on the Profile
/// tab, and every other tab kept showing the old colour until you manually
/// pulled to refresh it. This fetches once for the whole app, in a single
/// PostgREST embedded-resource query instead of two round trips, and every
/// tab observing it updates the moment it changes.
@MainActor
final class SupportedCountyStore: ObservableObject {
    @Published private(set) var countyName: String?

    /// Kept current by the app root whenever the signed-in user changes,
    /// e.g. `.task(id: auth.userId) { supportedCounty.userId = auth.userId }`.
    var userId: UUID? {
        didSet {
            guard userId != oldValue else { return }
            guard let userId else {
                countyName = nil
                return
            }
            Task { await refresh(userId: userId) }
        }
    }

    /// Called right after Profile's "Save county" succeeds, using the name
    /// it already has loaded -- updates every tab's background instantly,
    /// with no extra round trip.
    func setCountyName(_ name: String?) {
        countyName = name
    }

    private struct CountyEmbed: Decodable { let name: String }
    private struct ProfileEmbed: Decodable {
        let supportedCountyId: UUID?
        let counties: CountyEmbed?
    }

    private func refresh(userId: UUID) async {
        do {
            let rows: [ProfileEmbed] = try await Supa.client
                .from("user_profiles")
                .select("supported_county_id, counties(name)")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            countyName = rows.first?.counties?.name
        } catch {
            print("SupportedCountyStore.refresh failed: \(error)")
        }
    }
}
