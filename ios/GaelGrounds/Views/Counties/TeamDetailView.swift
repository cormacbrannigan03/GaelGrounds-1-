import SwiftUI
import Supabase

struct TeamDetailView: View {
    let team: CountyTeam
    let countyName: String

    @State private var upcoming: [MatchSummary] = []
    @State private var results: [MatchSummary] = []
    @State private var alternateGrounds: [Ground] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        CountyBanner(countyName: countyName, height: 26)
                        Text(countyName).font(.title.bold())
                    }
                    Text("\(team.sportCode.icon) \(team.sportCode.label)")
                        .foregroundStyle(.secondary)
                    if let year = team.foundedYear {
                        Text("Founded \(year)").font(.caption).foregroundStyle(.secondary)
                    }
                    if let manager = team.currentManager {
                        Text("Manager: \(manager)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.brandGold).frame(width: 4)
                }

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    if !upcoming.isEmpty {
                        section("Upcoming fixtures") {
                            VStack(spacing: 10) {
                                ForEach(upcoming) { match in
                                    MatchCardView(match: match)
                                }
                            }
                        }
                    }

                    if !alternateGrounds.isEmpty {
                        section("Alternate Grounds") {
                            VStack(spacing: 10) {
                                ForEach(alternateGrounds) { ground in
                                    NavigationLink(value: GroundRoute(id: ground.id)) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.brandGold)
                                            Text(ground.name)
                                                .font(.body)
                                            Spacer()
                                            if let cap = ground.capacity {
                                                Text(cap.formatted())
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    section("Recent results") {
                        if results.isEmpty {
                            Text("No results found.")
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(results) { match in
                                    MatchCardView(match: match)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("\(countyName) \(team.sportCode.label)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MatchRoute.self) { route in
            MatchDetailView(matchId: route.id)
        }
        .navigationDestination(for: GroundRoute.self) { route in
            GroundDetailView(groundId: route.id)
        }
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

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let matches = try await MatchService.fetchMatches(forTeamId: team.id)
            let summaries = try await MatchService.resolveSummaries(matches)
            upcoming = summaries.filter { $0.isUpcoming || $0.isLive }
            results  = summaries.filter { $0.isPast }
            let groundIds = Array(Set(upcoming.compactMap(\.groundId)))
            if !groundIds.isEmpty {
                alternateGrounds = try await Supa.client
                    .from("grounds").select().in("id", values: groundIds).execute().value
            } else {
                alternateGrounds = []
            }
        } catch {
            print("TeamDetailView load failed: \(error)")
        }
    }
}
