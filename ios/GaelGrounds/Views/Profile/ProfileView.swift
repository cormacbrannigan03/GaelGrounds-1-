import SwiftUI
import Supabase

private struct VisitedGroundRow: Identifiable {
    let id: UUID
    let name: String
    let visitedAt: Date
}

private struct AttendedMatchRow: Identifiable {
    let id: UUID
    let competition: String?
    let playedAt: Date
    let homeName: String
    let awayName: String
}

private struct AchievementRow: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let unlockedAt: Date
}

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel

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
                    StatTile(value: grounds.count, label: "Grounds visited")
                    StatTile(value: matches.count, label: "Matches attended")
                    StatTile(value: achievements.count, label: "Achievements")
                }

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
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
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
                                        Text("🏆 \(a.title)").font(.headline)
                                        Text(a.description).font(.caption).foregroundStyle(.secondary)
                                        Text("Unlocked \(Formatting.shortDate(a.unlockedAt))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
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
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(m.homeName) v \(m.awayName)").font(.subheadline.bold())
                                        Text("\(m.competition ?? "Gaelic Games") · \(Formatting.matchDate(m.playedAt))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
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
                                    HStack {
                                        Text(g.name).font(.subheadline.bold())
                                        Spacer()
                                        Text(Formatting.shortDate(g.visitedAt)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }

                Button("Sign out") {
                    Task { await auth.signOut() }
                }
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Profile")
        .task { await load() }
        .refreshable { await load() }
        .gaelGroundsBackground()
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
            let groundNameById = Dictionary(uniqueKeysWithValues: groundRows.map { ($0.id, $0.name) })
            grounds = visits.map {
                VisitedGroundRow(id: $0.id, name: groundNameById[$0.groundId] ?? "Unknown ground", visitedAt: $0.visitedAt)
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
                    return AttendedMatchRow(id: a.id, competition: s.competition, playedAt: playedAt, homeName: s.homeName, awayName: s.awayName)
                }
            } else {
                matches = []
            }

            let userAchievements: [UserAchievement] = try await Supa.client
                .from("user_achievements").select().eq("user_id", value: userId).order("unlocked_at", ascending: false).execute().value
            let achievementIds = userAchievements.map(\.achievementId)
            if !achievementIds.isEmpty {
                let defs: [AchievementDefinition] = try await Supa.client
                    .from("achievement_definitions").select().in("id", values: achievementIds).execute().value
                let defById = Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
                achievements = userAchievements.compactMap { ua in
                    guard let d = defById[ua.achievementId] else { return nil }
                    return AchievementRow(id: ua.id, title: d.title, description: d.description, unlockedAt: ua.unlockedAt)
                }
            } else {
                achievements = []
            }
        } catch {
            print("Profile load failed: \(error)")
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
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}
