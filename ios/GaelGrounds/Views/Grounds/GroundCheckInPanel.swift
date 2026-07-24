import SwiftUI
import Supabase

private struct Visitor: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let displayName: String?
    let visitedAt: Date
    let notes: String?
}

struct GroundCheckInPanel: View {
    let groundId: UUID

    @EnvironmentObject private var auth: AuthViewModel

    @State private var visitors: [Visitor] = []
    @State private var myVisitId: UUID?
    @State private var notes = ""
    @State private var isLoading = true
    @State private var isBusy = false
    @State private var unlockedTitles: [String]?
    @State private var realtimeTask: Task<Void, Never>?
    @State private var channel: RealtimeChannelV2?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Visitors").font(.headline)
                Text("Updates live as fans check in").font(.caption).foregroundStyle(.secondary)
            }

            if auth.isSignedIn {
                if let myVisitId {
                    Button {
                        Task { await undo(myVisitId) }
                    } label: {
                        Text("✓ Checked in — undo")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Add a note (optional) — e.g. \"Here for the Munster final\"", text: $notes)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            Task { await checkIn() }
                        } label: {
                            Text("📍 Check in here").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brandGreen)
                        .controlSize(.large)
                        .disabled(isBusy)
                    }
                }
            }

            if let unlockedTitles {
                Button {
                    self.unlockedTitles = nil
                } label: {
                    Text("🏆 Achievement unlocked: \(unlockedTitles.joined(separator: ", "))")
                        .font(.footnote.bold())
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.brandGold.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }

            if isLoading {
                ProgressView()
            } else if visitors.isEmpty {
                Text("No check-ins yet — be the first!").foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(visitors) { visitor in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(Color.brandGreenLight).frame(width: 8, height: 8).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(visitor.displayName ?? "A fan")
                                    Text("· \(Formatting.shortDate(visitor.visitedAt))")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                                if let notes = visitor.notes, !notes.isEmpty {
                                    Text("\"\(notes)\"").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if visitor.userId == auth.userId {
                                Spacer()
                                Text("YOU").font(.caption2.bold()).foregroundStyle(.brandGold)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .task { await start() }
        .onDisappear { stop() }
    }

    private func start() async {
        await loadVisitors()
        isLoading = false
        subscribeToRealtime()
    }

    private func stop() {
        realtimeTask?.cancel()
        Task { await channel?.unsubscribe() }
    }

    private func subscribeToRealtime() {
        let ch = Supa.client.realtimeV2.channel("ground-visits-\(groundId.uuidString)")
        let changes = ch.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_visits",
            filter: "ground_id=eq.\(groundId.uuidString)"
        )
        channel = ch

        realtimeTask = Task {
            await ch.subscribe()
            for await _ in changes {
                await loadVisitors()
            }
        }
    }

    private func loadVisitors() async {
        do {
            let rows: [UserVisit] = try await Supa.client
                .from("user_visits")
                .select()
                .eq("ground_id", value: groundId)
                .order("visited_at", ascending: false)
                .limit(25)
                .execute()
                .value

            let userIds = Array(Set(rows.map(\.userId)))
            let profiles: [UserProfile] = userIds.isEmpty ? [] : try await Supa.client
                .from("user_profiles").select().in("id", values: userIds).execute().value
            let nameById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.displayName) })

            visitors = rows.map {
                Visitor(id: $0.id, userId: $0.userId, displayName: nameById[$0.userId] ?? nil, visitedAt: $0.visitedAt, notes: $0.notes)
            }
            myVisitId = rows.first { $0.userId == auth.userId }?.id
        } catch {
            print("loadVisitors failed: \(error)")
        }
    }

    private func checkIn() async {
        guard let userId = auth.userId else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            try await Supa.client
                .from("user_visits")
                .insert(UserVisitInsert(groundId: groundId, userId: userId, notes: trimmed.isEmpty ? nil : trimmed))
                .execute()
            notes = ""
            let newTitles = await AchievementsService.evaluate(userId: userId)
            if !newTitles.isEmpty { unlockedTitles = newTitles }
        } catch {
            print("checkIn failed: \(error)")
        }
    }

    private func undo(_ visitId: UUID) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await Supa.client.from("user_visits").delete().eq("id", value: visitId).execute()
        } catch {
            print("undo failed: \(error)")
        }
    }
}
