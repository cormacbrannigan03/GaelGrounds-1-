import SwiftUI
import Supabase

private struct FriendAchievementRow: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let unlockedAt: Date
}

struct FriendProfileView: View {
    let userId: UUID

    @State private var profile: UserProfile?
    @State private var visitCount = 0
    @State private var matchCount = 0
    @State private var achievements: [FriendAchievementRow] = []
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
                        StatTile(value: achievements.count, label: "Achievements")
                    }

                    if !achievements.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Achievements").font(.title3.bold())
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
                }
            }
            .padding()
        }
        .navigationTitle(profile?.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .gaelGroundsBackground()
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

            visitCount = try await visitsTask.count
            matchCount = try await attendanceTask.count

            let userAchievements = try await userAchievementsTask
            let achievementIds = userAchievements.map(\.achievementId)
            if !achievementIds.isEmpty {
                let defs: [AchievementDefinition] = try await Supa.client
                    .from("achievement_definitions").select().in("id", values: achievementIds).execute().value
                let defById = Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
                achievements = userAchievements.compactMap { ua in
                    guard let d = defById[ua.achievementId] else { return nil }
                    return FriendAchievementRow(id: ua.id, title: d.title, description: d.description, unlockedAt: ua.unlockedAt)
                }
            }
        } catch {
            print("FriendProfileView load failed: \(error)")
        }
    }
}
