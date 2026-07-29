import SwiftUI
import Supabase

struct MatchesView: View {
    private enum Filter { case all, upcoming, results }

    @State private var matches: [MatchSummary] = []
    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var isLoading = true
    @State private var isSearching = false
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var realtimeTask: Task<Void, Never>?
    @State private var searchTask: Task<Void, Never>?

    /// `matches` is already whatever's relevant to the current search (or
    /// the recent-first default) -- this just applies the All/Upcoming/
    /// Results segmented filter on top of that already-loaded set.
    private var filtered: [MatchSummary] {
        switch filter {
        case .all: return matches
        case .upcoming: return matches.filter(\.isUpcoming)
        case .results: return matches.filter(\.hasScore)
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
                    .onChange(of: search) { newValue in
                        scheduleSearch(newValue)
                    }

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
                        if isSearching {
                            ProgressView().frame(maxWidth: .infinity)
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
            await load(showSpinner: true)
            let (channel, task) = RealtimeWatcher.watch(table: "matches") { Task { await load(showSpinner: false) } }
            realtimeChannel = channel
            realtimeTask = task
        }
        .onDisappear { RealtimeWatcher.stop(channel: realtimeChannel, task: realtimeTask) }
        .refreshable { await load(showSpinner: false) }
    }

    /// Debounces search-as-you-type so each keystroke doesn't fire its own
    /// network round trip.
    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await load(showSpinner: false)
        }
    }

    /// With no search text this loads only the most recent matches (see
    /// `MatchService.fetchRecent` -- this app's ~8,000-match archive made
    /// fetching everything on every visit the main reason this screen was
    /// slow to load). Typing a search runs a dedicated server-side query
    /// that reaches the full history instead of requiring it all in memory.
    private func load(showSpinner: Bool) async {
        if showSpinner { isLoading = true } else { isSearching = true }
        defer { isLoading = false; isSearching = false }
        do {
            let rows = search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? try await MatchService.fetchRecent()
                : try await MatchService.search(search)
            matches = try await MatchService.resolveSummaries(rows)
        } catch {
            print("Matches load failed: \(error)")
        }
    }
}
