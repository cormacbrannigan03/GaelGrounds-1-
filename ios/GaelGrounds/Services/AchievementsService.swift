import Foundation

/// Evaluates achievement_definitions.rule_type against the signed-in user's
/// current stats and inserts any newly-earned rows into user_achievements.
/// Safe to call after every check-in — RLS still enforces user_id = auth.uid()
/// on the insert, and we only ever add achievements the user doesn't have yet.
enum AchievementsService {
    static func evaluate(userId: UUID, checkedInMatchId: UUID? = nil) async -> AchievementEvaluation {
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
            let attendanceRows = try await attendance
            let matchCount = attendanceRows.count

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

            // County achievements only count when the county is both the designated
            // home team and the venue belongs to that county. This excludes neutral
            // championship venues even if the county happens to be listed first.
            let homeCounts = try await homeMatchCounts(attendance: attendanceRows)
            var eligibleHomeKey: HomeAchievementKey?
            if let checkedInMatchId {
                let checkedInMatch: Match = try await Supa.client
                    .from("matches")
                    .select()
                    .eq("id", value: checkedInMatchId)
                    .single()
                    .execute()
                    .value

                if let homeTeamId = checkedInMatch.homeCountyTeamId,
                   let groundId = checkedInMatch.groundId {
                    async let homeTeamTask: CountyTeam = Supa.client
                        .from("county_teams")
                        .select()
                        .eq("id", value: homeTeamId)
                        .single()
                        .execute()
                        .value
                    async let groundTask: Ground = Supa.client
                        .from("grounds")
                        .select()
                        .eq("id", value: groundId)
                        .single()
                        .execute()
                        .value
                    let (homeTeam, ground) = try await (homeTeamTask, groundTask)
                    if homeTeam.countyId == ground.countyId {
                        eligibleHomeKey = HomeAchievementKey(
                            countyId: homeTeam.countyId,
                            sportCode: homeTeam.sportCode
                        )
                    }
                }
            }

            var newlyUnlocked: [UserAchievementInsert] = []
            var unlocks: [AchievementUnlock] = []

            for def in defs where !unlockedIds.contains(def.id) {
                let earned: Bool
                switch def.ruleType {
                case "ground_visit_count":
                    earned = groundCount >= (def.ruleParams.count ?? 1)
                case "match_attendance_count":
                    earned = matchCount >= (def.ruleParams.count ?? 1)
                case "all_provinces_visited":
                    earned = provinces.count >= 4
                case "county_home_match":
                    if let countyId = def.ruleParams.countyId,
                       let sportCode = def.ruleParams.sportCode {
                        earned = (homeCounts[HomeAchievementKey(countyId: countyId, sportCode: sportCode)] ?? 0) >= 1
                    } else {
                        earned = false
                    }
                default:
                    earned = false
                }

                if earned {
                    newlyUnlocked.append(UserAchievementInsert(achievementId: def.id, userId: userId))
                    unlocks.append(
                        AchievementUnlock(
                            id: def.id,
                            title: def.title,
                            description: def.description,
                            icon: def.icon,
                            tier: def.ruleType == "county_home_match" ? .standard : nil
                        )
                    )
                }
            }

            if !newlyUnlocked.isEmpty {
                try await Supa.client.from("user_achievements").insert(newlyUnlocked).execute()
            }

            var progress: AchievementProgress?
            if let key = eligibleHomeKey,
               let definition = defs.first(where: {
                   $0.ruleType == "county_home_match"
                       && $0.ruleParams.countyId == key.countyId
                       && $0.ruleParams.sportCode == key.sportCode
               }) {
                let count = homeCounts[key] ?? 0
                let tier = AchievementTier.forHomeMatchCount(count)

                if [10, 25, 50].contains(count) {
                    unlocks.append(
                        AchievementUnlock(
                            id: UUID(),
                            title: "\(definition.title) — \(tier.label)",
                            description: "Attend \(count) verified home games.",
                            icon: definition.icon,
                            tier: tier
                        )
                    )
                }

                progress = AchievementProgress(
                    title: definition.title,
                    message: progressMessage(count: count),
                    icon: definition.icon,
                    tier: tier,
                    homeGameCount: count
                )
            }

            return AchievementEvaluation(unlocks: unlocks, progress: progress)
        } catch {
            print("AchievementsService.evaluate failed: \(error)")
            return AchievementEvaluation(unlocks: [], progress: nil)
        }
    }

    static func homeMatchCounts(userId: UUID) async throws -> [HomeAchievementKey: Int] {
        let attendance: [UserMatchAttendance] = try await Supa.client
            .from("user_match_attendance")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return try await homeMatchCounts(attendance: attendance)
    }

    private static func homeMatchCounts(attendance: [UserMatchAttendance]) async throws -> [HomeAchievementKey: Int] {
        let matchIds = Array(Set(attendance.map(\.matchId)))
        guard !matchIds.isEmpty else { return [:] }

        let matches: [Match] = try await Supa.client
            .from("matches")
            .select()
            .in("id", values: matchIds)
            .execute()
            .value
        let homeTeamIds = Array(Set(matches.compactMap(\.homeCountyTeamId)))
        let groundIds = Array(Set(matches.compactMap(\.groundId)))
        guard !homeTeamIds.isEmpty, !groundIds.isEmpty else { return [:] }

        async let teamsTask: [CountyTeam] = Supa.client
            .from("county_teams")
            .select()
            .in("id", values: homeTeamIds)
            .execute()
            .value
        async let groundsTask: [Ground] = Supa.client
            .from("grounds")
            .select()
            .in("id", values: groundIds)
            .execute()
            .value
        let (teams, grounds) = try await (teamsTask, groundsTask)
        let teamById = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
        let groundById = Dictionary(uniqueKeysWithValues: grounds.map { ($0.id, $0) })

        var counts: [HomeAchievementKey: Int] = [:]
        for match in matches {
            guard let teamId = match.homeCountyTeamId,
                  let groundId = match.groundId,
                  let team = teamById[teamId],
                  let ground = groundById[groundId],
                  team.countyId == ground.countyId else { continue }
            let key = HomeAchievementKey(countyId: team.countyId, sportCode: team.sportCode)
            counts[key, default: 0] += 1
        }
        return counts
    }

    static func progressMessage(count: Int) -> String {
        let next: (threshold: Int, name: String)?
        if count < 10 {
            next = (10, "Bronze")
        } else if count < 25 {
            next = (25, "Silver")
        } else if count < 50 {
            next = (50, "Gold")
        } else {
            next = nil
        }

        guard let next else {
            return "Outstanding — you've earned Gold level with \(count) home games."
        }
        let remaining = next.threshold - count
        let noun = remaining == 1 ? "game" : "games"
        return "Good work — you're only \(remaining) \(noun) away from earning \(next.name) level."
    }
}
