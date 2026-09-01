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

    @EnvironmentObject private var auth: AuthViewModel

    @State private var profile: UserProfile?
    @State private var countyName: String?
    @State private var visitCount = 0
    @State private var matchCount = 0
    @State private var favouriteAchievements: [FriendAchievementRow] = []
    @State private var totalAchievementCount = 0
    @State private var bestGame: FriendBestGame?
    @State private var isLoading = true

    @State private var relationship: FriendService.Relationship?
    @State private var isFriendActionBusy = false
    @State private var friendActionError: String?

    private var isSelf: Bool { userId == auth.userId }
    // Stats are only shown for yourself or once the friend request between
    // you and this person has actually been accepted -- someone who's only
    // sent/received a request, or a stranger, sees just the name, county
    // and the friend-action row.
    private var statsUnlocked: Bool { isSelf || relationship?.status == .friends }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile?.displayName ?? "A fan").font(.title2.bold())
                        if let countyName {
                            Text("Supports \(countyName)").foregroundStyle(.secondary)
                        } else {
                            Text("GaelGrounds member").foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.brandGold).frame(width: 4)
                    }

                    if !isSelf {
                        friendActionRow
                    }

                    if statsUnlocked {
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
                    } else {
                        Text("Add \(profile?.displayName ?? "this fan") as a friend to see their matches, grounds and achievements.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
        .countyBackground(countyName)
    }

    @ViewBuilder
    private var friendActionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                switch relationship?.status {
                case .friends:
                    Label("Friends", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.brandGreenLight)
                    Button("Remove friend") {
                        Task { await removeFriendship() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.secondary)
                    .disabled(isFriendActionBusy)
                case .sent:
                    Text("Friend request sent").font(.subheadline).foregroundStyle(.secondary)
                case .received:
                    Button("Accept friend request") {
                        Task { await respond(accept: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.brandGreen)
                    .disabled(isFriendActionBusy)
                    Button("Decline") {
                        Task { await respond(accept: false) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.secondary)
                    .disabled(isFriendActionBusy)
                case .unrelated, nil:
                    Button("+ Add friend") {
                        Task { await sendRequest() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.brandGreen)
                    .disabled(isFriendActionBusy)
                }
            }
            if let friendActionError {
                Text(friendActionError).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func sendRequest() async {
        guard let myId = auth.userId else { return }
        isFriendActionBusy = true
        friendActionError = nil
        defer { isFriendActionBusy = false }
        do {
            try await FriendService.sendRequest(from: myId, to: userId)
            relationship = try await FriendService.fetchRelationship(between: myId, and: userId)
        } catch {
            friendActionError = "Sending friend requests requires GaelGrounds Premium."
        }
    }

    private func respond(accept: Bool) async {
        guard let friendshipId = relationship?.friendshipId, let myId = auth.userId else { return }
        isFriendActionBusy = true
        defer { isFriendActionBusy = false }
        do {
            try await FriendService.respondToRequest(friendshipId: friendshipId, accept: accept)
            relationship = try await FriendService.fetchRelationship(between: myId, and: userId)
            if accept { await loadStats() }
        } catch {
            print("respond failed: \(error)")
        }
    }

    private func removeFriendship() async {
        guard let friendshipId = relationship?.friendshipId, let myId = auth.userId else { return }
        isFriendActionBusy = true
        defer { isFriendActionBusy = false }
        do {
            try await FriendService.removeFriendship(id: friendshipId)
            relationship = try await FriendService.fetchRelationship(between: myId, and: userId)
        } catch {
            print("removeFriendship failed: \(error)")
        }
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

            if let countyId = fetched.supportedCountyId {
                let county: County? = try? await Supa.client
                    .from("counties").select().eq("id", value: countyId).single().execute().value
                countyName = county?.name
            } else {
                countyName = nil
            }

            if !isSelf, let myId = auth.userId {
                relationship = try? await FriendService.fetchRelationship(between: myId, and: userId)
            }

            if statsUnlocked {
                await loadStats()
            }
        } catch {
            print("FriendProfileView load failed: \(error)")
        }
    }

    private func loadStats() async {
        do {
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

            if let bestMatchId = profile?.bestMatchId {
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
            print("FriendProfileView loadStats failed: \(error)")
        }
    }
}
