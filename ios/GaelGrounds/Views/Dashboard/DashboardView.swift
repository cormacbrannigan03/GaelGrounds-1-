import SwiftUI
import Supabase

struct DashboardView: View {
    @EnvironmentObject private var auth: AuthViewModel

    @State private var liveAndUpcoming: [MatchSummary] = []
    @State private var groundsVisited = 0
    @State private var matchesAttended = 0
    @State private var achievementsUnlocked = 0
    @State private var isLoading = true
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var realtimeTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Every ground. Every code. Every county.")
                        .font(.title.bold())
                    Text(
                        "Check in at Gaelic football, hurling, camogie and ladies' football matches in real time, " +
                        "and build your own record of the grounds you've stood in across all 32 counties."
                    )
                    .foregroundStyle(.secondary)
                }

                if auth.isSignedIn {
                    HStack(spacing: 12) {
                        StatTile(value: groundsVisited, label: "Grounds visited")
                        StatTile(value: matchesAttended, label: "Matches attended")
                        StatTile(value: achievementsUnlocked, label: "Achievements")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Live & upcoming").font(.title3.bold())
                        Spacer()
                        NavigationLink("See all fixtures →", value: MatchesRouteTag())
                    }

                    if isLoading {
                        ProgressView()
                    } else if liveAndUpcoming.isEmpty {
                        Text("No live or upcoming matches right now — check back soon.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(liveAndUpcoming) { match in
                                MatchCardView(match: match)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("GaelGrounds")
        .navigationDestination(for: MatchRoute.self) { route in
            MatchDetailView(matchId: route.id)
        }
        .navigationDestination(for: MatchesRouteTag.self) { _ in
            MatchesView()
        }
        .task {
            await load(showSpinner: true)
            let (channel, task) = RealtimeWatcher.watch(table: "matches") { Task { await load(showSpinner: false) } }
            realtimeChannel = channel
            realtimeTask = task
        }
        .onDisappear { RealtimeWatcher.stop(channel: realtimeChannel, task: realtimeTask) }
        .refreshable { await load(showSpinner: false) }
    }

    private func load(showSpinner: Bool) async {
        if showSpinner { isLoading = true }
        defer { if showSpinner { isLoading = false } }

        do {
            let matches = try await MatchService.fetchUpcomingAndLive()
            liveAndUpcoming = try await MatchService.resolveSummaries(matches)
        } catch {
            print("Dashboard load failed: \(error)")
        }

        guard let userId = auth.userId else { return }
        async let groundsCount = countRows("user_visits", userId: userId)
        async let matchesCount = countRows("user_match_attendance", userId: userId)
        async let achievementsCount = countRows("user_achievements", userId: userId)
        groundsVisited = await groundsCount
        matchesAttended = await matchesCount
        achievementsUnlocked = await achievementsCount
    }

    private func countRows(_ table: String, userId: UUID) async -> Int {
        (try? await Supa.client.from(table).select(head: true, count: .exact).eq("user_id", value: userId).execute().count) ?? 0
    }
}

/// Lightweight tag type so the "See all fixtures" link can push MatchesView
/// via the same NavigationStack-based `navigationDestination` pattern used
/// for detail routes.
private struct MatchesRouteTag: Hashable {}

private struct StatTile: View {
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
