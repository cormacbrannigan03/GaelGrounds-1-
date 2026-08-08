import SwiftUI
import Supabase

struct LeaderboardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var premium: PremiumStore
    @State private var showingPaywall = false

    enum Tab: String, CaseIterable {
        case overall  = "Overall"
        case myCounty = "My County"
        case ulster   = "Ulster"
        case munster  = "Munster"
        case leinster = "Leinster"
        case connacht = "Connacht"
        case bronze   = "Most Bronze"
        case silver   = "Most Silver"
        case gold     = "Top Gold"

        var province: Province? {
            switch self {
            case .overall, .myCounty, .bronze, .silver, .gold: return nil
            case .ulster:   return .ulster
            case .munster:  return .munster
            case .leinster: return .leinster
            case .connacht: return .connacht
            }
        }

        var tier: AchievementTier? {
            switch self {
            case .bronze: return .bronze
            case .silver: return .silver
            case .gold: return .gold
            default: return nil
            }
        }
    }

    enum SortKey: String, CaseIterable {
        case matches = "Matches"
        case grounds = "Grounds"
    }

    enum Scope: String, CaseIterable {
        case everyone = "Everyone"
        case friends  = "Friends"
    }

    @State private var entries:   [LeaderboardEntry] = []
    @State private var friendIds: Set<UUID> = []
    @State private var supportedCountyId: UUID?
    @State private var supportedCountyName: String?
    @State private var isLoading = true
    @State private var activeTab: Tab     = .overall
    @State private var sortBy:    SortKey = .matches
    @State private var scope:     Scope   = .everyone

    private var scoped: [LeaderboardEntry] {
        guard scope == .friends else { return entries }
        return entries.filter { $0.id == auth.userId || friendIds.contains($0.id) }
    }

    private var displayed: [LeaderboardEntry] {
        if activeTab == .myCounty {
            guard let supportedCountyId else { return [] }
            return sortedOverall(
                scoped.filter { $0.supportedCountyId == supportedCountyId }
            )
        }
        if let province = activeTab.province {
            return scoped
                .filter { ($0.provinceMatchCounts[province] ?? 0) > 0 }
                .sorted { ($0.provinceMatchCounts[province] ?? 0) > ($1.provinceMatchCounts[province] ?? 0) }
        }
        if let tier = activeTab.tier {
            return scoped
                .filter { $0.tierCounts[tier, default: 0] > 0 }
                .sorted { $0.tierCounts[tier, default: 0] > $1.tierCounts[tier, default: 0] }
        }
        return sortedOverall(scoped)
    }

    private func sortedOverall(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        switch sortBy {
        case .matches:
            return entries.sorted { $0.matchCount != $1.matchCount ? $0.matchCount > $1.matchCount : $0.groundCount > $1.groundCount }
        case .grounds:
            return entries.sorted { $0.groundCount != $1.groundCount ? $0.groundCount > $1.groundCount : $0.matchCount > $1.matchCount }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Scrollable tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button { activeTab = tab } label: {
                            Text(tab == .myCounty ? (supportedCountyName ?? tab.rawValue) : tab.rawValue)
                                .font(.subheadline.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    activeTab == tab
                                        ? Color.brandGreenLight
                                        : Color(.secondarySystemBackground),
                                    in: Capsule()
                                )
                                .foregroundStyle(activeTab == tab ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: activeTab)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(Color(.systemBackground).shadow(.drop(color: .black.opacity(0.06), radius: 2, y: 1)))

            // MARK: Content
            ScrollView {
                VStack(spacing: 14) {
                    if !premium.isPremium {
                        Button { showingPaywall = true } label: {
                            HStack {
                                Text("Go Premium to appear on the leaderboard")
                                    .font(.footnote.bold())
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding(10)
                            .background(Color.brandGold.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    Picker("Scope", selection: $scope) {
                        ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if activeTab == .overall || activeTab == .myCounty {
                        Picker("Sort by", selection: $sortBy) {
                            ForEach(SortKey.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if displayed.isEmpty {
                        Text(emptyMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(displayed.enumerated()), id: \.element.id) { index, entry in
                                LeaderboardRow(
                                    rank: index + 1,
                                    entry: entry,
                                    tab: activeTab,
                                    sortBy: sortBy,
                                    isCurrentUser: entry.id == auth.userId
                                )
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Leaderboard")
        .task { await load() }
        .refreshable { await load() }
        .countyBackground(supportedCountyName)
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView(reason: "Only Premium members appear on the leaderboard.")
        }
    }

    private var emptyMessage: String {
        if scope == .friends && friendIds.isEmpty {
            return "Add some friends to see how you compare against them."
        }
        if activeTab == .myCounty {
            if let supportedCountyName {
                return "No \(supportedCountyName) supporters have checked in yet."
            }
            return "Choose a supported county on your profile to unlock this leaderboard."
        }
        if let province = activeTab.province {
            return "No \(province.rawValue) matches attended yet."
        }
        if let tier = activeTab.tier {
            return "No \(tier.label) achievements unlocked yet."
        }
        return "No activity yet. Be the first to check in!"
    }

    // MARK: - Data loading

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let profilesTask: [UserProfile]        = Supa.client.from("user_profiles").select().execute().value
            async let attendanceTask: [AttendanceRecord] = Supa.client.from("user_match_attendance").select("user_id, match_id").execute().value
            async let visitsTask: [UserIdOnly]           = Supa.client.from("user_visits").select("user_id").execute().value
            async let matchTeamsTask: [MatchTeamRef]     = Supa.client.from("matches").select("id, home_county_team_id, away_county_team_id, ground_id").execute().value
            async let countyTeamsTask: [CountyTeamRef]   = Supa.client.from("county_teams").select("id, county_id, sport_code").execute().value
            async let countiesTask: [CountyProvinceRef]  = Supa.client.from("counties").select("id, name, province").execute().value
            async let groundsTask: [GroundCountyRef]     = Supa.client.from("grounds").select("id, county_id").execute().value
            async let userAchievementsTask: [UserAchievementRef] = Supa.client.from("user_achievements").select("user_id, achievement_id").execute().value
            async let achievementDefsTask: [AchievementDefinition] = Supa.client.from("achievement_definitions").select().execute().value

            let (profiles, attendance, visits, matchTeams, countyTeams, counties) =
                try await (profilesTask, attendanceTask, visitsTask, matchTeamsTask, countyTeamsTask, countiesTask)
            let (grounds, userAchievements, achievementDefs) =
                try await (groundsTask, userAchievementsTask, achievementDefsTask)

            // Build lookup maps
            let teamToCounty    = Dictionary(uniqueKeysWithValues: countyTeams.map { ($0.id, $0.countyId) })
            let countyToProvince = Dictionary(uniqueKeysWithValues: counties.map { ($0.id, $0.province) })
            let countyNames = Dictionary(uniqueKeysWithValues: counties.map { ($0.id, $0.name) })
            let currentProfile = profiles.first { $0.id == auth.userId }
            supportedCountyId = currentProfile?.supportedCountyId
            supportedCountyName = currentProfile?.supportedCountyId.flatMap { countyNames[$0] }

            if let uid = auth.userId {
                let friends = try await FriendService.fetchFriends(userId: uid)
                friendIds = Set(friends.map(\.id))
            } else {
                friendIds = []
            }

            // Province(s) for each match
            var matchProvinces: [UUID: Set<Province>] = [:]
            for m in matchTeams {
                var provs = Set<Province>()
                if let hid = m.homeCountyTeamId, let cid = teamToCounty[hid], let p = countyToProvince[cid] { provs.insert(p) }
                if let aid = m.awayCountyTeamId, let cid = teamToCounty[aid], let p = countyToProvince[cid] { provs.insert(p) }
                matchProvinces[m.id] = provs
            }

            // Attendance counts — overall and per province
            var overallMatchCounts: [UUID: Int] = [:]
            var provinceCounts = Dictionary(uniqueKeysWithValues: Province.allCases.map { ($0, [UUID: Int]()) })
            for a in attendance {
                overallMatchCounts[a.userId, default: 0] += 1
                for p in matchProvinces[a.matchId] ?? [] {
                    provinceCounts[p, default: [:]][a.userId, default: 0] += 1
                }
            }

            // Ground counts
            var groundCounts: [UUID: Int] = [:]
            for v in visits { groundCounts[v.userId, default: 0] += 1 }

            // Home/road match counts per user, per (county, sport) — the
            // same basis county_home_match/county_away_match achievements
            // are tiered on in AchievementsService, computed here globally
            // across every user instead of one at a time.
            struct TierKey: Hashable { let userId: UUID; let countyId: UUID; let sportCode: SportCode }
            let matchById = Dictionary(uniqueKeysWithValues: matchTeams.map { ($0.id, $0) })
            let groundCountyById = Dictionary(uniqueKeysWithValues: grounds.map { ($0.id, $0.countyId) })
            let teamSportById = Dictionary(uniqueKeysWithValues: countyTeams.map { ($0.id, $0.sportCode) })

            var homeCountsByUser: [TierKey: Int] = [:]
            var roadCountsByUser: [TierKey: Int] = [:]
            for a in attendance {
                guard let match = matchById[a.matchId],
                      let groundId = match.groundId,
                      let groundCountyId = groundCountyById[groundId] else { continue }
                let participatingTeamIds = [match.homeCountyTeamId, match.awayCountyTeamId].compactMap { $0 }
                for teamId in participatingTeamIds {
                    guard let teamCountyId = teamToCounty[teamId], let sportCode = teamSportById[teamId] else { continue }
                    let key = TierKey(userId: a.userId, countyId: teamCountyId, sportCode: sportCode)
                    if teamCountyId == groundCountyId {
                        homeCountsByUser[key, default: 0] += 1
                    } else {
                        roadCountsByUser[key, default: 0] += 1
                    }
                }
            }

            // Tally each user's unlocked county_home_match/county_away_match
            // achievements into bronze/silver/gold buckets for the tier
            // leaderboards ("Most Bronze", "Most Silver", "Top Gold").
            let defById = Dictionary(uniqueKeysWithValues: achievementDefs.map { ($0.id, $0) })
            var tierCountsByUser: [UUID: [AchievementTier: Int]] = [:]
            for ua in userAchievements {
                guard let def = defById[ua.achievementId],
                      def.ruleType == "county_home_match" || def.ruleType == "county_away_match",
                      let countyId = def.ruleParams.countyId,
                      let sportCode = def.ruleParams.sportCode else { continue }
                let key = TierKey(userId: ua.userId, countyId: countyId, sportCode: sportCode)
                let count = def.ruleType == "county_home_match" ? (homeCountsByUser[key] ?? 0) : (roadCountsByUser[key] ?? 0)
                let tier = AchievementTier.forHomeMatchCount(count)
                guard tier != .standard else { continue }
                tierCountsByUser[ua.userId, default: [:]][tier, default: 0] += 1
            }

            // Build entries
            let profileById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            let allIds = Set(overallMatchCounts.keys).union(groundCounts.keys)

            // Free accounts can browse the leaderboard but never appear on
            // it — only premium profiles are ranked.
            entries = allIds.compactMap { uid in
                guard let profile = profileById[uid], profile.isPremium else { return nil }
                let provMap = Dictionary(uniqueKeysWithValues: Province.allCases.map { ($0, provinceCounts[$0]?[uid] ?? 0) })
                return LeaderboardEntry(
                    id: uid,
                    displayName: profile.displayName ?? "Anonymous",
                    matchCount: overallMatchCounts[uid] ?? 0,
                    groundCount: groundCounts[uid] ?? 0,
                    provinceMatchCounts: provMap,
                    tierCounts: tierCountsByUser[uid] ?? [:],
                    supportedCountyId: profile.supportedCountyId
                )
            }
        } catch {
            print("Leaderboard load failed: \(error)")
        }
    }
}

// MARK: - Models

private struct LeaderboardEntry: Identifiable {
    let id: UUID
    let displayName: String
    let matchCount: Int
    let groundCount: Int
    let provinceMatchCounts: [Province: Int]
    let tierCounts: [AchievementTier: Int]
    let supportedCountyId: UUID?
}

private struct AttendanceRecord: Decodable {
    let userId: UUID
    let matchId: UUID
}

private struct UserIdOnly: Decodable {
    let userId: UUID
}

private struct MatchTeamRef: Decodable {
    let id: UUID
    let homeCountyTeamId: UUID?
    let awayCountyTeamId: UUID?
    let groundId: UUID?
}

private struct CountyTeamRef: Decodable {
    let id: UUID
    let countyId: UUID
    let sportCode: SportCode
}

private struct GroundCountyRef: Decodable {
    let id: UUID
    let countyId: UUID
}

private struct UserAchievementRef: Decodable {
    let userId: UUID
    let achievementId: UUID
}

private struct CountyProvinceRef: Decodable {
    let id: UUID
    let name: String
    let province: Province
}

// MARK: - Row

private struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let tab: LeaderboardView.Tab
    let sortBy: LeaderboardView.SortKey
    let isCurrentUser: Bool

    private var rankLabel: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    private var primaryCount: Int {
        if let tier = tab.tier { return entry.tierCounts[tier, default: 0] }
        if let p = tab.province { return entry.provinceMatchCounts[p] ?? 0 }
        return sortBy == .matches ? entry.matchCount : entry.groundCount
    }

    private var primaryLabel: String {
        if let tier = tab.tier { return tier.label.lowercased() }
        return tab.province != nil ? "matches" : (sortBy == .matches ? "matches" : "grounds")
    }

    private var secondaryText: String {
        if let tier = tab.tier {
            let others = AchievementTier.allCases
                .filter { $0 != .standard && $0 != tier }
                .map { "\(entry.tierCounts[$0, default: 0]) \($0.label.lowercased())" }
                .joined(separator: " · ")
            return others
        }
        if tab.province != nil {
            return "\(entry.matchCount) total · \(entry.groundCount) grounds"
        }
        return sortBy == .matches
            ? "\(entry.groundCount) grounds"
            : "\(entry.matchCount) matches"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(rankLabel)
                .font(rank <= 3 ? .title2 : .body.bold())
                .frame(width: 36, alignment: .center)
                .foregroundStyle(rank <= 3 ? .primary : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(secondaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(primaryCount)")
                    .font(.title3.bold())
                    .foregroundStyle(.brandGreenLight)
                Text(primaryLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser
                    ? Color.brandGold.opacity(0.12)
                    : Color(.secondarySystemBackground))
                .overlay {
                    if isCurrentUser {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.brandGold.opacity(0.5), lineWidth: 1)
                    }
                }
        }
    }
}
