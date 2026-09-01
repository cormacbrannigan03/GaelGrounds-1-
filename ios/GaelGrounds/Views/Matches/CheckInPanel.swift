import SwiftUI
import Supabase

private struct Attendee: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let displayName: String?
}

private struct AchievementUnlockBatch: Identifiable {
    let id = UUID()
    let achievements: [AchievementUnlock]
    let progress: AchievementProgress?
}

struct CheckInPanel: View {
    let matchId: UUID
    let matchPlayedAt: Date?
    let isPast: Bool

    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var premium: PremiumStore

    @State private var attendees: [Attendee] = []
    @State private var myAttendanceId: UUID?
    @State private var isLoading = true
    @State private var isBusy = false
    @State private var achievementPopup: AchievementUnlockBatch?
    @State private var realtimeTask: Task<Void, Never>?
    @State private var channel: RealtimeChannelV2?
    @State private var showingPaywall = false
    @State private var paywallReason: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isPast ? "Who was there" : "Who's here").font(.headline)
                    Text(isPast ? "Check in any time, even after the final whistle" : "Updates live as fans check in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if auth.isSignedIn {
                    checkInButton
                }
            }

            if isLoading {
                ProgressView()
            } else if attendees.isEmpty {
                Text("No one's checked in yet — be the first!").foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(attendees) { attendee in
                        HStack(spacing: 8) {
                            Circle().fill(Color.brandGreenLight).frame(width: 8, height: 8)
                            if attendee.userId == auth.userId {
                                Text(attendee.displayName ?? "A fan")
                                Spacer()
                                Text("YOU").font(.caption2.bold()).foregroundStyle(.brandGold)
                            } else {
                                NavigationLink(value: FriendProfileRoute(id: attendee.userId)) {
                                    Text(attendee.displayName ?? "A fan")
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .gaelCard(cornerRadius: 14)
        .task { await start() }
        .onDisappear { stop() }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView(reason: paywallReason)
        }
        .sheet(item: $achievementPopup) { batch in
            AchievementUnlockedView(achievements: batch.achievements, progress: batch.progress)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var checkInButton: some View {
        if let myAttendanceId {
            Button {
                Task { await checkOut(myAttendanceId) }
            } label: {
                Text("✓ \(isPast ? "Logged as attended" : "Checked in") — undo")
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)
        } else {
            Button {
                Task { await checkIn() }
            } label: {
                Text(isPast ? "🕘 I was there" : "📍 Check in")
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandGreen)
            .disabled(isBusy)
        }
    }

    private func start() async {
        guard auth.isSignedIn else {
            attendees = []
            myAttendanceId = nil
            isLoading = false
            return
        }
        await loadAttendees()
        isLoading = false
        subscribeToRealtime()
    }

    private func stop() {
        realtimeTask?.cancel()
        Task { await channel?.unsubscribe() }
    }

    private func subscribeToRealtime() {
        let ch = Supa.client.realtimeV2.channel("match-attendance-\(matchId.uuidString)")
        let changes = ch.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_match_attendance",
            filter: "match_id=eq.\(matchId.uuidString)"
        )
        channel = ch

        realtimeTask = Task {
            await ch.subscribe()
            for await _ in changes {
                await loadAttendees()
            }
        }
    }

    private func loadAttendees() async {
        do {
            let rows: [UserMatchAttendance] = try await Supa.client
                .from("user_match_attendance")
                .select()
                .eq("match_id", value: matchId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let userIds = Array(Set(rows.map(\.userId)))
            let profiles: [UserProfile] = userIds.isEmpty ? [] : try await Supa.client
                .from("user_profiles")
                .select()
                .in("id", values: userIds)
                .execute()
                .value
            let nameById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.displayName) })

            attendees = rows.map { Attendee(id: $0.id, userId: $0.userId, displayName: nameById[$0.userId] ?? nil) }
            myAttendanceId = rows.first { $0.userId == auth.userId }?.id
        } catch {
            print("loadAttendees failed: \(error)")
        }
    }

    private func checkIn() async {
        guard let userId = auth.userId else { return }

        if let matchPlayedAt, !premium.isPremium, !MatchService.isDateAllowedForFreeTier(matchPlayedAt) {
            paywallReason = "Matches before 2019 require Premium."
            showingPaywall = true
            return
        }

        isBusy = true
        defer { isBusy = false }

        guard await MatchService.canLogAnotherMatch(userId: userId, isPremium: premium.isPremium) else {
            paywallReason = "You've reached the 10-match free limit. Upgrade to log more."
            showingPaywall = true
            return
        }

        do {
            let evaluation = try await MatchService.checkIn(matchId: matchId, userId: userId)
            if !evaluation.unlocks.isEmpty || evaluation.progress != nil {
                achievementPopup = AchievementUnlockBatch(
                    achievements: evaluation.unlocks,
                    progress: evaluation.progress
                )
            }
        } catch {
            print("checkIn failed: \(error)")
        }
    }

    private func checkOut(_ attendanceId: UUID) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await Supa.client.from("user_match_attendance").delete().eq("id", value: attendanceId).execute()
        } catch {
            print("checkOut failed: \(error)")
        }
    }
}

private struct AchievementUnlockedView: View {
    let achievements: [AchievementUnlock]
    let progress: AchievementProgress?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text(achievements.isEmpty ? "Good work!" : "Congratulations!")
                .font(.largeTitle.bold())
            if !achievements.isEmpty {
                Text(achievements.count == 1 ? "You've unlocked an achievement" : "You've unlocked new achievements")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(achievements) { achievement in
                    HStack(spacing: 14) {
                        Image(systemName: achievement.icon ?? "trophy.fill")
                            .font(.title2)
                            .foregroundStyle(tierColour(achievement.tier))
                            .frame(width: 42, height: 42)
                            .background(Color.brandGreen, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(achievement.title).font(.headline)
                            Text(achievement.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            if let progress {
                VStack(spacing: 8) {
                    HStack {
                        Label(progress.title, systemImage: progress.icon ?? "trophy.fill")
                            .font(.headline)
                        Spacer()
                        Text("\(progress.homeGameCount) home games")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(min(progress.homeGameCount, 50)), total: 50)
                        .tint(tierColour(progress.tier))
                    Text(progress.message)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .gaelInsetCard(cornerRadius: 14)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
    }

    private func tierColour(_ tier: AchievementTier?) -> Color {
        switch tier {
        case .bronze: return Color(red: 0.72, green: 0.45, blue: 0.20)
        case .silver: return Color(red: 0.55, green: 0.60, blue: 0.66)
        case .gold: return .brandGold
        case .standard, nil: return .secondary
        }
    }
}
