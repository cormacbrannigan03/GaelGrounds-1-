import SwiftUI
import Supabase

private struct VisitedGroundRow: Identifiable {
    var id: UUID { groundId }
    let groundId: UUID
    let name: String
    let visitCount: Int
    let mostRecentVisit: Date
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
    let gameKindLabel: String
    let progressMessage: String?
}

private struct LockedAchievementRow: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let icon: String?
    let ruleType: String
    let countyId: UUID?
    let province: Province?
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
    @State private var lockedAchievements: [LockedAchievementRow] = []
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
                    if !achievements.isEmpty || !lockedAchievements.isEmpty {
                        NavigationLink(value: ProfileDestination.achievements) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Achievements").font(.title3.bold())
                                    Spacer()
                                    Text("\(achievements.count) of \(achievements.count + lockedAchievements.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                    ForEach(achievements.prefix(4)) { a in
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
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .gaelCard(cornerRadius: 14)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
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
                                            Text(g.visitCount == 1 ? "1 visit" : "\(g.visitCount) visits")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
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
                ProfileAchievementsView(
                    unlocked: achievements,
                    locked: lockedAchievements,
                    counties: counties,
                    supportedCountyId: savedSupportedCountyId
                )
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
            let visitsByGround = Dictionary(grouping: visits, by: \.groundId)
            grounds = visitsByGround.map { groundId, visitsHere in
                let ground = groundById[groundId]
                return VisitedGroundRow(
                    groundId: groundId,
                    name: ground?.name ?? "Unknown ground",
                    visitCount: visitsHere.count,
                    mostRecentVisit: visitsHere.map(\.visitedAt).max() ?? Date.distantPast,
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
            let homeCounts = (try? await AchievementsService.homeMatchCounts(userId: userId)) ?? [:]
            let roadCounts = (try? await AchievementsService.roadMatchCounts(userId: userId)) ?? [:]
            let allDefs: [AchievementDefinition] = try await Supa.client
                .from("achievement_definitions").select().execute().value
            let defById = Dictionary(uniqueKeysWithValues: allDefs.map { ($0.id, $0) })

            achievements = userAchievements.compactMap { ua in
                guard let d = defById[ua.achievementId] else { return nil }
                // For county_home_match/county_away_match achievements, always show
                // a tier/count (defaulting to 0 rather than nil) so every unlocked
                // county+sport achievement displays consistently -- previously a
                // sport with zero recorded games (e.g. football, if all check-ins
                // were at away/neutral grounds) showed no tier line at all, which
                // looked like the tier system only existed for the other sport.
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
                let tier = homeCount.map(AchievementTier.forHomeMatchCount)
                return AchievementRow(
                    id: ua.id,
                    title: d.title,
                    description: d.description,
                    icon: d.icon,
                    unlockedAt: ua.unlockedAt,
                    tier: tier,
                    homeGameCount: homeCount,
                    gameKindLabel: gameKind,
                    progressMessage: homeCount.map { AchievementsService.progressMessage(count: $0, kind: gameKind) }
                )
            }

            let unlockedDefIds = Set(userAchievements.map(\.achievementId))
            lockedAchievements = allDefs
                .filter { !unlockedDefIds.contains($0.id) }
                .map { d in
                    LockedAchievementRow(
                        id: d.id,
                        title: d.title,
                        description: d.description,
                        icon: d.icon,
                        ruleType: d.ruleType,
                        countyId: d.ruleParams.countyId,
                        province: d.ruleParams.province
                    )
                }
                .sorted { $0.title < $1.title }
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
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                ForEach(group.matches) { match in
                                    NavigationLink(value: MatchRoute(id: match.matchId)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Image(systemName: "ticket.fill").foregroundStyle(Color.brandGreenLight)
                                                Spacer()
                                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                                            }
                                            Text("\(match.homeName) v \(match.awayName)").font(.headline)
                                            Text(match.competition ?? "Gaelic Games").font(.caption).foregroundStyle(.secondary)
                                            Text(Formatting.matchDate(match.playedAt)).font(.caption).foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
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
            return GroundProvinceGroup(province: province, grounds: rows.sorted { $0.mostRecentVisit > $1.mostRecentVisit })
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
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                ForEach(group.grounds) { ground in
                                    NavigationLink(value: GroundRoute(id: ground.groundId)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Image(systemName: "mappin.circle.fill").foregroundStyle(Color.brandGreenLight)
                                                Spacer()
                                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                                            }
                                            Text(ground.name).font(.headline)
                                            Text(ground.visitCount == 1 ? "1 visit" : "\(ground.visitCount) visits")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct CountyAchievementGroup: Identifiable {
    let countyId: UUID
    let countyName: String
    let achievements: [LockedAchievementRow]
    var id: UUID { countyId }
}

private struct ProvinceAchievementGroup: Identifiable {
    let province: Province
    let ownAchievement: LockedAchievementRow?
    let counties: [CountyAchievementGroup]
    var id: String { province.rawValue }
}

private struct ProfileAchievementsView: View {
    let unlocked: [AchievementRow]
    let locked: [LockedAchievementRow]
    let counties: [County]
    let supportedCountyId: UUID?

    private enum Tab: String, CaseIterable {
        case unlocked = "Unlocked"
        case locked = "Locked"
    }

    private static let provinceOrder: [Province] = [.leinster, .munster, .connacht, .ulster]
    private static let supporterRuleTypes: Set<String> = ["county_home_match", "county_away_match"]

    @State private var tab: Tab = .unlocked
    @State private var isSupportersExpanded = true
    @State private var isCountiesExpanded = false
    @State private var isProvincesExpanded = false
    @State private var expandedProvinces: Set<Province> = []

    private var countyNameById: [UUID: String] {
        Dictionary(uniqueKeysWithValues: counties.map { ($0.id, $0.name) })
    }

    private var provinceByCountyId: [UUID: Province] {
        Dictionary(uniqueKeysWithValues: counties.map { ($0.id, $0.province) })
    }

    // Home + Road Traveller achievements for the user's own supported county
    // specifically -- shown up front in their own section, separate from
    // (and in addition to) the generic "Counties" dropdown covering everyone.
    private var supporterLocked: [LockedAchievementRow] {
        guard let supportedCountyId else { return [] }
        return locked
            .filter { $0.countyId == supportedCountyId && Self.supporterRuleTypes.contains($0.ruleType) }
            .sorted { $0.title < $1.title }
    }

    // Anything with no county/province attached -- ground/match counts,
    // "all provinces visited," and the top-level "Ireland Complete" --
    // split into a couple of labeled sections rather than one flat,
    // unheaded grid.
    private static let groundRuleTypes: Set<String> = ["ground_visit_count", "all_provinces_visited", "country_grounds_complete"]

    private var groundsLocked: [LockedAchievementRow] {
        locked.filter { $0.countyId == nil && $0.province == nil && Self.groundRuleTypes.contains($0.ruleType) }
    }

    private var matchesLocked: [LockedAchievementRow] {
        locked.filter { $0.countyId == nil && $0.province == nil && !Self.groundRuleTypes.contains($0.ruleType) }
    }

    private var countyGroups: [CountyAchievementGroup] {
        let byCounty = Dictionary(grouping: locked.filter { $0.countyId != nil }, by: { $0.countyId! })
        return byCounty
            .map { countyId, rows in
                CountyAchievementGroup(
                    countyId: countyId,
                    countyName: countyNameById[countyId] ?? "Unknown county",
                    achievements: rows.sorted { $0.title < $1.title }
                )
            }
            .sorted { $0.countyName < $1.countyName }
    }

    private var provinceGroups: [ProvinceAchievementGroup] {
        let ownByProvince = Dictionary(uniqueKeysWithValues: locked.filter { $0.province != nil }.map { ($0.province!, $0) })
        let countiesByProvince = Dictionary(grouping: countyGroups) { provinceByCountyId[$0.countyId] }
        return Self.provinceOrder.compactMap { province in
            let own = ownByProvince[province]
            let countiesHere = (countiesByProvince[province] ?? []).sorted { $0.countyName < $1.countyName }
            guard own != nil || !countiesHere.isEmpty else { return nil }
            return ProvinceAchievementGroup(province: province, ownAchievement: own, counties: countiesHere)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                switch tab {
                case .unlocked:
                    if unlocked.isEmpty {
                        ContentUnavailableView("No achievements yet", systemImage: "trophy", description: Text("Check in to games to start unlocking achievements."))
                            .padding(.top, 80)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                            ForEach(unlocked) { achievement in
                                ProfileAchievementCard(achievement: achievement)
                            }
                        }
                        .padding()
                    }
                case .locked:
                    if locked.isEmpty {
                        ContentUnavailableView("All achievements unlocked!", systemImage: "trophy.fill", description: Text("You've earned everything there is right now."))
                            .padding(.top, 80)
                    } else {
                        VStack(spacing: 10) {
                            if !supporterLocked.isEmpty {
                                DisclosureGroup(isExpanded: $isSupportersExpanded) {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                        ForEach(supporterLocked) { achievement in
                                            ProfileLockedAchievementCard(achievement: achievement)
                                        }
                                    }
                                    .padding(.top, 8)
                                } label: {
                                    HStack {
                                        Text("Supporters Unlocks").font(.headline)
                                        Spacer()
                                        Text("\(supporterLocked.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .gaelCard(cornerRadius: 14)
                            }

                            if !groundsLocked.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Grounds").font(.headline)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                        ForEach(groundsLocked) { achievement in
                                            ProfileLockedAchievementCard(achievement: achievement)
                                        }
                                    }
                                }
                                .padding()
                                .gaelCard(cornerRadius: 14)
                            }

                            if !matchesLocked.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Matches").font(.headline)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                        ForEach(matchesLocked) { achievement in
                                            ProfileLockedAchievementCard(achievement: achievement)
                                        }
                                    }
                                }
                                .padding()
                                .gaelCard(cornerRadius: 14)
                            }

                            if !countyGroups.isEmpty {
                                DisclosureGroup(isExpanded: $isCountiesExpanded) {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                        ForEach(countyGroups.flatMap(\.achievements)) { achievement in
                                            ProfileLockedAchievementCard(achievement: achievement)
                                        }
                                    }
                                    .padding(.top, 8)
                                } label: {
                                    HStack {
                                        Text("Counties").font(.headline)
                                        Spacer()
                                        Text("\(countyGroups.flatMap(\.achievements).count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .gaelCard(cornerRadius: 14)
                            }

                            if !provinceGroups.isEmpty {
                                DisclosureGroup(isExpanded: $isProvincesExpanded) {
                                    VStack(spacing: 8) {
                                        ForEach(provinceGroups) { group in
                                            DisclosureGroup(isExpanded: provinceExpanded(group.province)) {
                                                VStack(alignment: .leading, spacing: 10) {
                                                    if let own = group.ownAchievement {
                                                        ProfileLockedAchievementCard(achievement: own)
                                                    }
                                                    ForEach(group.counties) { county in
                                                        VStack(alignment: .leading, spacing: 6) {
                                                            Text(county.countyName).font(.subheadline.bold())
                                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                                                ForEach(county.achievements) { achievement in
                                                                    ProfileLockedAchievementCard(achievement: achievement)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                .padding(.top, 8)
                                            } label: {
                                                Text(group.province.rawValue).font(.subheadline.bold())
                                            }
                                            .padding()
                                            .gaelInsetCard(cornerRadius: 10)
                                        }
                                    }
                                    .padding(.top, 8)
                                } label: {
                                    HStack {
                                        Text("Provinces").font(.headline)
                                        Spacer()
                                        Text("\(provinceGroups.count)")
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
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CountyRoute.self) { route in
            CountyDetailView(countyId: route.id)
        }
        .gaelGroundsBackground()
    }

    private func provinceExpanded(_ province: Province) -> Binding<Bool> {
        Binding(
            get: { expandedProvinces.contains(province) },
            set: { isExpanded in
                if isExpanded { expandedProvinces.insert(province) } else { expandedProvinces.remove(province) }
            }
        )
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
                Text(tier == .standard ? "\(count) \(achievement.gameKindLabel) games" : "\(tier.label) · \(count) \(achievement.gameKindLabel) games")
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

private struct ProfileLockedAchievementCard: View {
    let achievement: LockedAchievementRow

    private var content: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(achievement.title, systemImage: "lock.fill")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(achievement.description).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isCountyComplete {
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
        }
        .padding()
        .gaelCard(cornerRadius: 14)
        .opacity(0.6)
    }

    // Only "Complete a county" achievements have somewhere useful to link
    // to -- tapping through shows the grounds that make up that county's
    // completion target.
    private var isCountyComplete: Bool {
        achievement.ruleType == "county_grounds_complete" && achievement.countyId != nil
    }

    var body: some View {
        if isCountyComplete, let countyId = achievement.countyId {
            NavigationLink(value: CountyRoute(id: countyId)) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
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
