import SwiftUI
import Supabase

private struct VisitedGroundRow: Identifiable {
    let id: UUID
    let groundId: UUID
    let name: String
    let visitedAt: Date
    let province: Province
}

private struct AttendedMatchRow: Identifiable {
    let id: UUID
    let matchId: UUID
    let competition: String?
    let playedAt: Date
    let homeName: String
    let awayName: String
}

private enum ProfileDestination: Hashable {
    case grounds
    case matches
    case achievements
}

private struct AchievementRow: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let icon: String?
    let unlockedAt: Date
    let tier: AchievementTier?
    let homeGameCount: Int?
    let progressMessage: String?
}

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var premium: PremiumStore

    @State private var showingPaywall = false
    @State private var displayName = ""
    @State private var savedName = ""
    @State private var grounds: [VisitedGroundRow] = []
    @State private var matches: [AttendedMatchRow] = []
    @State private var achievements: [AchievementRow] = []
    @State private var counties: [County] = []
    @State private var supportedCountyId: UUID?
    @State private var savedSupportedCountyId: UUID?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var isSavingCounty = false
    @State private var realtimeTask: Task<Void, Never>?
    @State private var channel: RealtimeChannelV2?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(savedName.isEmpty ? "Your profile" : savedName).font(.title2.bold())
                    if let email = auth.userEmail {
                        Text(email).foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Display name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await saveDisplayName() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces) == savedName)
                }

                HStack(spacing: 8) {
                    Picker("Supported county", selection: $supportedCountyId) {
                        Text("Select your county").tag(nil as UUID?)
                        ForEach(counties) { county in
                            Text(county.name).tag(county.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()

                    Button(isSavingCounty ? "Saving…" : "Save county") {
                        Task { await saveSupportedCounty() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        isSavingCounty ||
                        supportedCountyId == nil ||
                        supportedCountyId == savedSupportedCountyId
                    )
                }

                HStack(spacing: 12) {
                    NavigationLink(value: ProfileDestination.grounds) {
                        StatTile(value: grounds.count, label: "Grounds visited")
                    }
                    NavigationLink(value: ProfileDestination.matches) {
                        StatTile(value: matches.count, label: "Matches attended")
                    }
                    NavigationLink(value: ProfileDestination.achievements) {
                        StatTile(value: achievements.count, label: "Achievements")
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FriendsView()
                } label: {
                    HStack {
                        Label("Friends", systemImage: "person.2.fill")
                            .font(.subheadline.bold())
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding()
                    .gaelCard(cornerRadius: 14)
                }
                .buttonStyle(.plain)

                Button { showingPaywall = true } label: {
                    HStack {
                        Label(
                            premium.isPremium ? "Premium" : "Go Premium",
                            systemImage: premium.isPremium ? "checkmark.seal.fill" : "star.fill"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(premium.isPremium ? .brandGold : .primary)
                        Spacer()
                        if premium.isPremium, let expiresAt = premium.premiumExpiresAt {
                            Text("Renews \(Formatting.shortDate(expiresAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if !premium.isPremium {
                            Text("€1.99/mo").font(.caption).foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding()
                    .gaelCard(cornerRadius: 14)
                }
                .buttonStyle(.plain)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    if !achievements.isEmpty {
                        section("Achievements") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                ForEach(achievements) { a in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label(a.title, systemImage: a.icon ?? "trophy.fill")
                                            .font(.headline)
                                            .foregroundStyle(a.tier?.tint ?? Color.brandGold)
                                        if let tier = a.tier, let count = a.homeGameCount {
                                            Text(tier == .standard ? "\(count) home games" : "\(tier.label) · \(count) home games")
                                                .font(.caption.bold())
                                                .foregroundStyle(tier.tint)
                                        }
                                        Text(a.description).font(.caption).foregroundStyle(.secondary)
                                        if let progressMessage = a.progressMessage {
                                            Text(progressMessage)
                                                .font(.caption)
                                                .foregroundStyle(.primary)
                                        }
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

                    section("Matches attended") {
                        if matches.isEmpty {
                            Text("No matches logged yet — find a match to check in to.").foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(matches) { m in
                                    NavigationLink(value: MatchRoute(id: m.matchId)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\(m.homeName) v \(m.awayName)").font(.subheadline.bold())
                                                Text("\(m.competition ?? "Gaelic Games") · \(Formatting.matchDate(m.playedAt))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .gaelCard(cornerRadius: 10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    section("Grounds visited") {
                        if grounds.isEmpty {
                            Text("No grounds logged yet — browse grounds to check in.").foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(grounds) { g in
                                    NavigationLink(value: GroundRoute(id: g.groundId)) {
                                        HStack {
                                            Text(g.name).font(.subheadline.bold())
                                            Spacer()
                                            Text(Formatting.shortDate(g.visitedAt)).font(.caption).foregroundStyle(.secondary)
                                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .gaelCard(cornerRadius: 10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                Button("Sign out") {
                    Task { await auth.signOut() }
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Link("Privacy Policy", destination: URL(string: "https://www.gaelgrounds.ie/privacy.html")!)
                    Link("Terms of Service", destination: URL(string: "https://www.gaelgrounds.ie/terms.html")!)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationDestination(for: ProfileDestination.self) { destination in
            switch destination {
            case .grounds:
                ProfileGroundsHistoryView(grounds: grounds)
            case .matches:
                ProfileMatchesHistoryView(matches: matches)
            case .achievements:
                ProfileAchievementsView(achievements: achievements)
            }
        }
        .navigationDestination(for: MatchRoute.self) { route in
            MatchDetailView(matchId: route.id)
        }
        .navigationDestination(for: GroundRoute.self) { route in
            GroundDetailView(groundId: route.id)
        }
        .task { await start() }
        .onDisappear { stop() }
        .refreshable { await load() }
        .countyBackground(supportedCountyName)
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
    }

    private var supportedCountyName: String? {
        counties.first { $0.id == savedSupportedCountyId }?.name
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content()
        }
    }

    private func saveDisplayName() async {
        guard let userId = auth.userId else { return }
        isSaving = true
        defer { isSaving = false }
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        do {
            try await Supa.client
                .from("user_profiles")
                .update(UserProfileUpdate(displayName: trimmed))
                .eq("id", value: userId)
                .execute()
            savedName = trimmed
        } catch {
            print("saveDisplayName failed: \(error)")
        }
    }

    private func saveSupportedCounty() async {
        guard let userId = auth.userId, let supportedCountyId else { return }
        isSavingCounty = true
        defer { isSavingCounty = false }
        do {
            try await Supa.client
                .from("user_profiles")
                .update(SupportedCountyUpdate(supportedCountyId: supportedCountyId))
                .eq("id", value: userId)
                .execute()
            savedSupportedCountyId = supportedCountyId
        } catch {
            print("saveSupportedCounty failed: \(error)")
        }
    }

    private func start() async {
        await load()
        subscribeToRealtime()
    }

    private func stop() {
        realtimeTask?.cancel()
        Task { await channel?.unsubscribe() }
    }

    // Reloads whenever a check-in, ground visit, or achievement changes for
    // this user, so the Profile tab's stats stay current without needing a
    // manual pull-to-refresh when a check-in happens elsewhere (e.g. on a
    // match's CheckInPanel) while this tab stays mounted in the background.
    private func subscribeToRealtime() {
        guard let userId = auth.userId else { return }
        let ch = Supa.client.realtimeV2.channel("profile-\(userId.uuidString)")
        let attendanceChanges = ch.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_match_attendance",
            filter: "user_id=eq.\(userId.uuidString)"
        )
        let visitChanges = ch.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_visits",
            filter: "user_id=eq.\(userId.uuidString)"
        )
        let achievementChanges = ch.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_achievements",
            filter: "user_id=eq.\(userId.uuidString)"
        )
        channel = ch

        realtimeTask = Task {
            await ch.subscribe()
            await withTaskGroup(of: Void.self) { group in
                group.addTask { for await _ in attendanceChanges { await load() } }
                group.addTask { for await _ in visitChanges { await load() } }
                group.addTask { for await _ in achievementChanges { await load() } }
            }
        }
    }

    private func load() async {
        guard let userId = auth.userId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let profileTask: UserProfile = Supa.client
                .from("user_profiles").select().eq("id", value: userId).single().execute().value
            async let countiesTask: [County] = Supa.client
                .from("counties").select().order("name").execute().value
            let (profile, loadedCounties) = try await (profileTask, countiesTask)
            counties = loadedCounties
            supportedCountyId = profile.supportedCountyId
            savedSupportedCountyId = profile.supportedCountyId
            if let name = profile.displayName {
                displayName = name
                savedName = name
            }

            let visits: [UserVisit] = try await Supa.client
                .from("user_visits").select().eq("user_id", value: userId).order("visited_at", ascending: false).execute().value
            let groundIds = Array(Set(visits.map(\.groundId)))
            let groundRows: [Ground] = groundIds.isEmpty ? [] : try await Supa.client
                .from("grounds").select().in("id", values: groundIds).execute().value
            let groundById = Dictionary(uniqueKeysWithValues: groundRows.map { ($0.id, $0) })
            let provinceByCountyId = Dictionary(uniqueKeysWithValues: loadedCounties.map { ($0.id, $0.province) })
            grounds = visits.map { v in
                let ground = groundById[v.groundId]
                return VisitedGroundRow(
                    id: v.id,
                    groundId: v.groundId,
                    name: ground?.name ?? "Unknown ground",
                    visitedAt: v.visitedAt,
                    province: ground.flatMap { provinceByCountyId[$0.countyId] } ?? .leinster
                )
            }

            let attendance: [UserMatchAttendance] = try await Supa.client
                .from("user_match_attendance").select().eq("user_id", value: userId).order("created_at", ascending: false).execute().value
            let matchIds = attendance.map(\.matchId)
            if !matchIds.isEmpty {
                let matchRows: [Match] = try await Supa.client.from("matches").select().in("id", values: matchIds).execute().value
                let summaries = try await MatchService.resolveSummaries(matchRows)
                let summaryById = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
                matches = attendance.compactMap { a in
                    guard let s = summaryById[a.matchId], let playedAt = s.playedAt else { return nil }
                    return AttendedMatchRow(
                        id: a.id,
                        matchId: a.matchId,
                        competition: s.competition,
                        playedAt: playedAt,
                        homeName: s.homeName,
                        awayName: s.awayName
                    )
                }
            } else {
                matches = []
            }

            let userAchievements: [UserAchievement] = try await Supa.client
                .from("user_achievements").select().eq("user_id", value: userId).order("unlocked_at", ascending: false).execute().value
            let achievementIds = userAchievements.map(\.achievementId)
            let homeCounts = (try? await AchievementsService.homeMatchCounts(userId: userId)) ?? [:]
            if !achievementIds.isEmpty {
                let defs: [AchievementDefinition] = try await Supa.client
                    .from("achievement_definitions").select().in("id", values: achievementIds).execute().value
                let defById = Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
                achievements = userAchievements.compactMap { ua in
                    guard let d = defById[ua.achievementId] else { return nil }
                    let homeCount: Int?
                    if d.ruleType == "county_home_match",
                       let countyId = d.ruleParams.countyId,
                       let sportCode = d.ruleParams.sportCode {
                        homeCount = homeCounts[HomeAchievementKey(countyId: countyId, sportCode: sportCode)]
                    } else {
                        homeCount = nil
                    }
                    let tier = homeCount.map(AchievementTier.forHomeMatchCount)
                    return AchievementRow(
                        id: ua.id,
                        title: d.title,
                        description: d.description,
                        icon: d.icon,
                        unlockedAt: ua.unlockedAt,
                        tier: tier,
                        homeGameCount: homeCount,
                        progressMessage: homeCount.map(AchievementsService.progressMessage)
                    )
                }
            } else {
                achievements = []
            }
        } catch {
            print("Profile load failed: \(error)")
        }
    }
}

private struct MatchYearGroup: Identifiable {
    let year: Int
    let matches: [AttendedMatchRow]
    var id: Int { year }
}

private struct ProfileMatchesHistoryView: View {
    let matches: [AttendedMatchRow]

    @State private var expandedYears: Set<Int>

    init(matches: [AttendedMatchRow]) {
        self.matches = matches
        let calendar = Calendar.current
        let years = Set(matches.map { calendar.component(.year, from: $0.playedAt) })
        _expandedYears = State(initialValue: years.max().map { [$0] } ?? [])
    }

    private var groupedByYear: [MatchYearGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: matches) { calendar.component(.year, from: $0.playedAt) }
        return grouped
            .map { MatchYearGroup(year: $0.key, matches: $0.value.sorted { $0.playedAt > $1.playedAt }) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        ScrollView {
            if matches.isEmpty {
                ContentUnavailableView("No matches attended", systemImage: "ticket", description: Text("Games you check in to will appear here."))
                    .padding(.top, 80)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(groupedByYear) { group in
                        DisclosureGroup(isExpanded: isExpanded(group.year)) {
                            VStack(spacing: 8) {
                                ForEach(group.matches) { match in
                                    NavigationLink(value: MatchRoute(id: match.matchId)) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "ticket.fill").foregroundStyle(Color.brandGreenLight)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text("\(match.homeName) v \(match.awayName)").font(.headline)
                                                Text(match.competition ?? "Gaelic Games").font(.subheadline).foregroundStyle(.secondary)
                                                Text(Formatting.matchDate(match.playedAt)).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                                        }
                                        .padding()
                                        .gaelInsetCard(cornerRadius: 10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Text(String(group.year)).font(.headline)
                                Spacer()
                                Text("\(group.matches.count) match\(group.matches.count == 1 ? "" : "es")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .gaelCard(cornerRadius: 14)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Matches attended")
        .navigationBarTitleDisplayMode(.inline)
        .gaelGroundsBackground()
    }

    private func isExpanded(_ year: Int) -> Binding<Bool> {
        Binding(
            get: { expandedYears.contains(year) },
            set: { isExpanded in
                if isExpanded { expandedYears.insert(year) } else { expandedYears.remove(year) }
            }
        )
    }
}

private struct GroundProvinceGroup: Identifiable {
    let province: Province
    let grounds: [VisitedGroundRow]
    var id: String { province.rawValue }
}

private struct ProfileGroundsHistoryView: View {
    let grounds: [VisitedGroundRow]

    // Matches the order already used for the Leaderboard's province tabs.
    private static let provinceOrder: [Province] = [.ulster, .munster, .leinster, .connacht]

    @State private var expandedProvinces: Set<Province>

    init(grounds: [VisitedGroundRow]) {
        self.grounds = grounds
        let provincesWithVisits = Set(grounds.map(\.province))
        let firstNonEmpty = Self.provinceOrder.first { provincesWithVisits.contains($0) }
        _expandedProvinces = State(initialValue: firstNonEmpty.map { [$0] } ?? [])
    }

    private var groupedByProvince: [GroundProvinceGroup] {
        let grouped = Dictionary(grouping: grounds, by: \.province)
        return Self.provinceOrder.compactMap { province in
            guard let rows = grouped[province], !rows.isEmpty else { return nil }
            return GroundProvinceGroup(province: province, grounds: rows.sorted { $0.visitedAt > $1.visitedAt })
        }
    }

    var body: some View {
        ScrollView {
            if grounds.isEmpty {
                ContentUnavailableView("No grounds visited", systemImage: "mappin.and.ellipse", description: Text("Grounds from your match check-ins will appear here."))
                    .padding(.top, 80)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(groupedByProvince) { group in
                        DisclosureGroup(isExpanded: isExpanded(group.province)) {
                            VStack(spacing: 8) {
                                ForEach(group.grounds) { ground in
                                    NavigationLink(value: GroundRoute(id: ground.groundId)) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "mappin.circle.fill").foregroundStyle(Color.brandGreenLight)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(ground.name).font(.headline)
                                                Text("Visited \(Formatting.shortDate(ground.visitedAt))").font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                                        }
                                        .padding()
                                        .gaelInsetCard(cornerRadius: 10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Text(group.province.rawValue).font(.headline)
                                Spacer()
                                Text("\(group.grounds.count) ground\(group.grounds.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .gaelCard(cornerRadius: 14)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Grounds visited")
        .navigationBarTitleDisplayMode(.inline)
        .gaelGroundsBackground()
    }

    private func isExpanded(_ province: Province) -> Binding<Bool> {
        Binding(
            get: { expandedProvinces.contains(province) },
            set: { isExpanded in
                if isExpanded { expandedProvinces.insert(province) } else { expandedProvinces.remove(province) }
            }
        )
    }
}

private struct ProfileAchievementsView: View {
    let achievements: [AchievementRow]

    var body: some View {
        ScrollView {
            if achievements.isEmpty {
                ContentUnavailableView("No achievements yet", systemImage: "trophy", description: Text("Check in to games to start unlocking achievements."))
                    .padding(.top, 80)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(achievements) { achievement in
                        ProfileAchievementCard(achievement: achievement)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .gaelGroundsBackground()
    }
}

private struct ProfileAchievementCard: View {
    let achievement: AchievementRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(achievement.title, systemImage: achievement.icon ?? "trophy.fill")
                .font(.headline)
                .foregroundStyle(achievement.tier?.tint ?? Color.brandGold)
            if let tier = achievement.tier, let count = achievement.homeGameCount {
                Text(tier == .standard ? "\(count) home games" : "\(tier.label) · \(count) home games")
                    .font(.caption.bold())
                    .foregroundStyle(tier.tint)
            }
            Text(achievement.description).font(.caption).foregroundStyle(.secondary)
            if let progressMessage = achievement.progressMessage {
                Text(progressMessage).font(.caption).foregroundStyle(.primary)
            }
            Text("Unlocked \(Formatting.shortDate(achievement.unlockedAt))").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .gaelCard(cornerRadius: 14)
    }
}

struct StatTile: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.title.bold()).foregroundStyle(.brandGreenLight)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .gaelCard(cornerRadius: 14)
    }
}
