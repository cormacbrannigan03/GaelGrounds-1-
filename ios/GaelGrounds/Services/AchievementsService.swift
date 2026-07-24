import Foundation

/// Evaluates achievement_definitions.rule_type against the signed-in user's
/// current stats and inserts any newly-earned rows into user_achievements.
/// Safe to call after every check-in — RLS still enforces user_id = auth.uid()
/// on the insert, and we only ever add achievements the user doesn't have yet.
enum AchievementsService {
    static func evaluate(userId: UUID) async -> [String] {
        do {
            async let definitions: [AchievementDefinition] = Supa.client
                .from("achievement_definitions")
                .select()
                .execute()
                .value

            async let unlocked: [UserAchievement] = Supa.client
                .from("user_achievements")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            async let visits: [UserVisit] = Supa.client
                .from("user_visits")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            async let attendance: [UserMatchAttendance] = Supa.client
                .from("user_match_attendance")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            let defs = try await definitions
            let unlockedIds = Set(try await unlocked.map(\.achievementId))
            let visitRows = try await visits
            let matchCount = try await attendance.count

            let groundIds = Array(Set(visitRows.map(\.groundId)))
            var provinces = Set<Province>()
            if !groundIds.isEmpty {
                let grounds: [Ground] = try await Supa.client
                    .from("grounds")
                    .select()
                    .in("id", values: groundIds)
                    .execute()
                    .value
                let countyIds = Array(Set(grounds.map(\.countyId)))
                if !countyIds.isEmpty {
                    let counties: [County] = try await Supa.client
                        .from("counties")
                        .select()
                        .in("id", values: countyIds)
                        .execute()
                        .value
                    provinces = Set(counties.map(\.province))
                }
            }
            let groundCount = groundIds.count

            var newlyUnlocked: [UserAchievementInsert] = []
            var newTitles: [String] = []

            for def in defs where !unlockedIds.contains(def.id) {
                let earned: Bool
                switch def.ruleType {
                case "ground_visit_count":
                    earned = groundCount >= (def.ruleParams.count ?? 1)
                case "match_attendance_count":
                    earned = matchCount >= (def.ruleParams.count ?? 1)
                case "all_provinces_visited":
                    earned = provinces.count >= 4
                default:
                    earned = false
                }

                if earned {
                    newlyUnlocked.append(UserAchievementInsert(achievementId: def.id, userId: userId))
                    newTitles.append(def.title)
                }
            }

            if !newlyUnlocked.isEmpty {
                try await Supa.client.from("user_achievements").insert(newlyUnlocked).execute()
            }

            return newTitles
        } catch {
            print("AchievementsService.evaluate failed: \(error)")
            return []
        }
    }
}
