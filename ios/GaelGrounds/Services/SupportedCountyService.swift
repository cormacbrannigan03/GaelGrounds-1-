import Foundation
import Supabase

/// Resolves the signed-in user's chosen supported county to a display name,
/// used to tint each main tab's background via `.countyBackground(_:)`
/// (Home, Matches, Grounds, Counties, Leaderboard, Profile) -- but not the
/// detail screens reached by tapping into a specific county/ground/match,
/// which already tint themselves to whichever county they're showing.
enum SupportedCountyService {
    static func fetchName(userId: UUID) async -> String? {
        guard let profile: UserProfile = try? await Supa.client
            .from("user_profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value,
            let countyId = profile.supportedCountyId
        else { return nil }

        let county: County? = try? await Supa.client
            .from("counties")
            .select()
            .eq("id", value: countyId)
            .single()
            .execute()
            .value
        return county?.name
    }
}
