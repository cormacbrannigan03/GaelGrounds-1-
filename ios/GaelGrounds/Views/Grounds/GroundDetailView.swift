import SwiftUI
import PostgREST
import Supabase

private struct GameSeenHereRow: Identifiable {
    let id: UUID
    let matchId: UUID
    let competition: String?
    let playedAt: Date
    let homeName: String
    let awayName: String
}

struct GroundDetailView: View {
    let groundId: UUID

    @EnvironmentObject private var auth: AuthViewModel

    @State private var ground: Ground?
    @State private var countyName: String?
    @State private var isLoading = true
    @State private var gamesSeenHere: [GameSeenHereRow] = []
    @State private var isGamesSeenHereExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let ground {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ground.name).font(.title2.bold())
                        if let countyName {
                            Text(countyName).foregroundStyle(.secondary)
                        }
                        if let capacity = ground.capacity {
                            Text("Capacity: \(capacity.formatted())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Link("View on map →", destination: mapURL(for: ground))
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.brandGold).frame(width: 4)
                    }

                    if !gamesSeenHere.isEmpty {
                        DisclosureGroup(isExpanded: $isGamesSeenHereExpanded) {
                            VStack(spacing: 8) {
                                ForEach(gamesSeenHere) { game in
                                    NavigationLink(value: MatchRoute(id: game.matchId)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\(game.homeName) v \(game.awayName)").font(.subheadline.bold())
                                                Text("\(game.competition ?? "Gaelic Games") · \(Formatting.matchDate(game.playedAt))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
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
                                Text("Games you've seen here").font(.headline)
                                Spacer()
                                Text("\(gamesSeenHere.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .gaelCard(cornerRadius: 14)
                    }

                    GroundCheckInPanel(groundId: ground.id)
                } else {
                    Text("Ground not found.").foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Ground")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MatchRoute.self) { route in
            MatchDetailView(matchId: route.id)
        }
        .task { await load() }
        .countyBackground(countyName)
    }

    private func mapURL(for ground: Ground) -> URL {
        let name = ground.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ground.name
        return URL(string: "https://maps.apple.com/?ll=\(ground.latitude),\(ground.longitude)&q=\(name)")!
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let g: Ground = try await Supa.client.from("grounds").select().eq("id", value: groundId).single().execute().value
            ground = g
            let county: County = try await Supa.client.from("counties").select().eq("id", value: g.countyId).single().execute().value
            countyName = county.name

            if let userId = auth.userId {
                let matchesHere: [Match] = try await Supa.client
                    .from("matches").select().eq("ground_id", value: groundId).execute().value
                let matchIdsHere = Set(matchesHere.map(\.id))
                guard !matchIdsHere.isEmpty else {
                    gamesSeenHere = []
                    return
                }

                let attendance: [UserMatchAttendance] = try await Supa.client
                    .from("user_match_attendance").select().eq("user_id", value: userId).execute().value
                let myAttendanceHere = attendance.filter { matchIdsHere.contains($0.matchId) }
                guard !myAttendanceHere.isEmpty else {
                    gamesSeenHere = []
                    return
                }

                let attendedMatches = matchesHere.filter { match in
                    myAttendanceHere.contains { $0.matchId == match.id }
                }
                let summaries = try await MatchService.resolveSummaries(attendedMatches)
                let summaryById = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
                gamesSeenHere = myAttendanceHere
                    .compactMap { attendance -> GameSeenHereRow? in
                        guard let summary = summaryById[attendance.matchId], let playedAt = summary.playedAt else { return nil }
                        return GameSeenHereRow(
                            id: attendance.id,
                            matchId: attendance.matchId,
                            competition: summary.competition,
                            playedAt: playedAt,
                            homeName: summary.homeName,
                            awayName: summary.awayName
                        )
                    }
                    .sorted { $0.playedAt > $1.playedAt }
            }
        } catch {
            print("GroundDetail load failed: \(error)")
        }
    }
}
