import SwiftUI
import Supabase

struct MatchDetailView: View {
    let matchId: UUID

    @State private var summary: MatchSummary?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let summary {
                    header(for: summary)
                    CheckInPanel(matchId: summary.id, isPast: summary.isPast)
                } else {
                    Text("Match not found.").foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .gaelGroundsBackground()
    }

    @ViewBuilder
    private func header(for summary: MatchSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.competition ?? "Gaelic Games")
                    .font(.caption.bold())
                    .foregroundStyle(.brandGold)
                    .textCase(.uppercase)
                if summary.isLive {
                    Text("● LIVE")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.brandLive, in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            Text("\(summary.homeName) v \(summary.awayName)")
                .font(.title2.bold())

            if summary.hasScore {
                Text("\(summary.homeScore ?? "") – \(summary.awayScore ?? "")")
                    .font(.title.bold())
                    .foregroundStyle(.brandGreenLight)
            }

            Text(Formatting.matchDate(summary.playedAt)).foregroundStyle(.secondary)

            if let groundName = summary.groundName {
                Text("📍 \(groundName)").foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.brandGold).frame(width: 4)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let match: Match = try await Supa.client
                .from("matches")
                .select()
                .eq("id", value: matchId)
                .single()
                .execute()
                .value
            summary = try await MatchService.resolveSummaries([match]).first
        } catch {
            print("MatchDetail load failed: \(error)")
        }
    }
}
