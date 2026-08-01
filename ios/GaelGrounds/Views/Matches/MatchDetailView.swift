import SwiftUI
import Supabase

struct MatchDetailView: View {
    let matchId: UUID
    var isFinalOnLoad: Bool = false
    var winnerNameOnLoad: String? = nil

    @State private var summary: MatchSummary?
    @State private var isLoading = true
    @State private var confettiWinner: String?

    var body: some View {
        ZStack {
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
            .countyBackground(winnerNameOnLoad ?? summary?.winnerName)

            if let winner = confettiWinner {
                let (primary, secondary) = CountyColours.colours(for: winner)
                ConfettiOverlayView(colors: [primary, secondary])
            }
        }
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isFinalOnLoad, let winner = winnerNameOnLoad {
                confettiWinner = winner
            }
        }
        .task { await load() }
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

            Text(summary.playedAt.map(Formatting.matchDate) ?? "Date unavailable")
                .foregroundStyle(.secondary)

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
            if confettiWinner == nil, let s = summary, s.isFinal, let winner = s.winnerName {
                confettiWinner = winner
            }
        } catch {
            print("MatchDetail load failed: \(error)")
        }
    }
}
