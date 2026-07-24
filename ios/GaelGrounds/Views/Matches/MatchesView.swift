import SwiftUI
import Supabase

struct MatchesView: View {
    private enum Filter { case all, upcoming, results }

    @State private var matches: [MatchSummary] = []
    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var isLoading = true
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var realtimeTask: Task<Void, Never>?

    private var filtered: [MatchSummary] {
        var list = matches
        switch filter {
        case .all: break
        case .upcoming: list = list.filter(\.isUpcoming)
        case .results: list = list.filter(\.hasScore)
        }

        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return list }
        return list.filter { m in
            m.homeName.lowercased().contains(q)
                || m.awayName.lowercased().contains(q)
                || (m.competition ?? "").lowercased().contains(q)
                || (m.groundName ?? "").lowercased().contains(q)
                || m.season.map(String.init) == q
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Missed checking in on the day? Find the match below and check in any time — even years later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Search by team, competition, ground or year…", text: $search)
                    .textFieldStyle(.roundedBorder)

                Picker("Filter", selection: $filter) {
                    Text("All").tag(Filter.all)
                    Text("Upcoming").tag(Filter.upcoming)
                    Text("Results").tag(Filter.results)
                }
                .pickerStyle(.segmented)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if filtered.isEmpty {
                    Text("No matches to show.").foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { match in
                            MatchCardView(match: match)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Fixtures & results")
        .navigationDestination(for: MatchRoute.self) { route in
            MatchDetailView(matchId: route.id)
        }
        .task {
            await load()
            let (channel, task) = RealtimeWatcher.watch(table: "matches") { Task { await load() } }
            realtimeChannel = channel
            realtimeTask = task
        }
        .onDisappear { RealtimeWatcher.stop(channel: realtimeChannel, task: realtimeTask) }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows = try await MatchService.fetchAll()
            matches = try await MatchService.resolveSummaries(rows)
        } catch {
            print("Matches load failed: \(error)")
        }
    }
}
