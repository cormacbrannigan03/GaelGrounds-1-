import SwiftUI
import Supabase

private struct FriendAchievementRow: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let icon: String?
    let unlockedAt: Date
    let tier: AchievementTier?
    let homeGameCount: Int?
    let gameKindLabel: String
}

private struct FriendBestGame {
    let matchId: UUID
    let competition: String?
    let playedAt: Date?
    let homeName: String
    let awayName: String
    let homeScore: String?
    let awayScore: String?
    let groundName: String?
}

struct FriendProfileView: View {
    let userId: UUID

    @State private var profile: UserProfile?
    @State private var visitCount = 0
    @State private var matchCount = 0
    @State private var favouriteAchievements: [FriendAchievementRow] = []
    @State private var totalAchievementCount = 0
    @State private var bestGame: FriendBestGame?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile?.displayName ?? "A fan").font(.title2.bold())
                        Text("GaelGrounds member").foregroundStyle(.secondary)
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.brandGold).frame(width: 4)
                    }

                    HStack(spacing: 12) {
                        StatTile(value: visitCount, label: "Grounds visited")
                        StatTile(value: matchCount, label: "Matches attended")
                        StatTile(value: totalAchievementCount, label: "Achievements")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "star.circle.fill").foregroundStyle(.blue)
                            Text("Best Game Ever").font(.title3.bold())
                        }
                        if let bestGame {
                            NavigationLink(value: MatchRoute(id: bestGame.matchId)) {
                                bestGameCard(bestGame)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("Hasn't picked a best game yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !favouriteAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Favourite achievements").font(.title3.bold())
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                ForEach(favouriteAchievements) { a in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label(a.title, systemImage: a.icon ?? "trophy.fill")
                                            .font(.headline)
                                            .foregroundStyle(a.tier?.tint ?? Color.brandGold)
                                        if let tier = a.tier, let count = a.homeGameCount {
                                            Text(tier == .standard ? "\(count) \(a.gameKindLabel) games" : "\(tier.label) · \(count) \(a.gameKindLabel) games")
                                                .font(.caption.bold())
                                                .foregroundStyle(tier.tint)
                                        }
                                        Text(a.description).font(.caption).foregroundStyle(.secondary)
                                        Text("Unlocked \(Formatting.shortDate(a.unlockedAt))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .gaelCard(cornerRadius: 14)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(profile?.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MatchRoute.self) { route in
            MatchDetailView(matchId: route.id)
        }
        .task { await load() }
        .gaelGroundsBackground()
    }

    @ViewBuilder
    private func bestGameCard(_ game: FriendBestGame) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.competition ?? "Gaelic Games")
                .font(.caption.bold())
                .foregroundStyle(.brandGold)
                .textCase(.uppercase)

            HStack {
                Text(game.homeName).font(.title3.bold()).lineLimit(1)
                Spacer()
                if let homeScore = game.homeScore, let awayScore = game.awayScore {
                    Text("\(homeScore) – \(awayScore)")
                        .font(.title3.bold())
                        .foregroundStyle(.brandGreenLight)
                } else {
                    Text("v").font(.title3.bold()).foregroundStyle(.brandGreenLight)
                }
                Spacer()
                Text(game.awayName).font(.title3.bold()).lineLimit(1).multilineTextAlignment(.trailing)
            }

            HStack(spacing: 6) {
                Text(game.playedAt.map(Formatting.matchDate) ?? "Date unavailable")
                if let groundName = game.groundName {
                    Text("· \(groundName)")
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .gaelCard(cornerRadius: 14)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched: UserProfile = try await Supa.client
                .from("user_profiles").select().eq("id", value: userId).single().execute().value
            profile = fetched

            async let visitsTask: [UserVisit] = Supa.client
                .from("user_visits").select().eq("user_id", value: userId).execute().value
            async let attendanceTask: [UserMatchAttendance] = Supa.client
                .from("user_match_attendance").select().eq("user_id", value: userId).execute().value
            async let userAchievementsTask: [UserAchievement] = Supa.client
                .from("user_achievements").select().eq("user_id", value: userId)
                .order("unlocked_at", ascending: false).execute().value
            async let homeCountsTask = AchievementsService.homeMatchCounts(userId: userId)
            async let roadCountsTask = AchievementsService.roadMatchCounts(userId: userId)

            // A raw row count counts every check-in, not every ground --
            // checking into the same ground for multiple matches is
            // multiple rows but one ground.
            visitCount = Set(try await visitsTask.map(\.groundId)).count
            matchCount = try await attendanceTask.count

            let userAchievements = try await userAchievementsTask
            totalAchievementCount = userAchievements.count
            let homeCounts = (try? await homeCountsTask) ?? [:]
            let roadCounts = (try? await roadCountsTask) ?? [:]

            let achievementIds = userAchievements.map(\.achievementId)
            if !achievementIds.isEmpty {
                let defs: [AchievementDefinition] = try await Supa.client
                    .from("achievement_definitions").select().in("id", values: achievementIds).execute().value
                let defById = Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })

                let rows: [FriendAchievementRow] = userAchievements.compactMap { ua in
                    guard let d = defById[ua.achievementId] else { return nil }
                    let homeCount: Int?
                    let gameKind: String
                    if d.ruleType == "county_home_match",
                       let countyId = d.ruleParams.countyId,
                       let sportCode = d.ruleParams.sportCode {
                        homeCount = homeCounts[HomeAchievementKey(countyId: countyId, sportCode: sportCode)] ?? 0
                        gameKind = "home"
                    } else if d.ruleType == "county_away_match",
                              let countyId = d.ruleParams.countyId,
                              let sportCode = d.ruleParams.sportCode {
                        homeCount = roadCounts[HomeAchievementKey(countyId: countyId, sportCode: sportCode)] ?? 0
                        gameKind = "road"
                    } else {
                        homeCount = nil
                        gameKind = "home"
                    }
                    return FriendAchievementRow(
                        id: ua.id,
                        title: d.title,
                        description: d.description,
                        icon: d.icon,
                        unlockedAt: ua.unlockedAt,
                        tier: homeCount.map(AchievementTier.forHomeMatchCount),
                        homeGameCount: homeCount,
                        gameKindLabel: gameKind
                    )
                }

                let pinned = userAchievements.filter(\.pinned).map(\.id)
                let pinnedRows = rows.filter { pinned.contains($0.id) }
                favouriteAchievements = pinnedRows.isEmpty ? Array(rows.prefix(4)) : pinnedRows
            } else {
                favouriteAchievements = []
            }

            if let bestMatchId = fetched.bestMatchId {
                let match: Match? = try? await Supa.client
                    .from("matches").select().eq("id", value: bestMatchId).single().execute().value
                if let match {
                    let summaries = try await MatchService.resolveSummaries([match])
                    if let summary = summaries.first {
                        bestGame = FriendBestGame(
                            matchId: summary.id,
                            competition: summary.competition,
                            playedAt: summary.playedAt,
                            homeName: summary.homeName,
                            awayName: summary.awayName,
                            homeScore: summary.homeScore,
                            awayScore: summary.awayScore,
                            groundName: summary.groundName
                        )
                    }
                }
            } else {
                bestGame = nil
            }
        } catch {
            print("FriendProfileView load failed: \(error)")
        }
    }
}
