import Foundation
import Supabase

enum SupportedCountyService {
    static func fetchName(userId: UUID) async -> String? {
        do {
            let profiles: [UserProfile] = try await Supa.client
                .from("user_profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            guard let countyId = profiles.first?.supportedCountyId else { return nil }
            let counties: [County] = try await Supa.client
                .from("counties")
                .select()
                .eq("id", value: countyId)
                .limit(1)
                .execute()
                .value
            return counties.first?.name
        } catch {
            return nil
        }
    }
}
