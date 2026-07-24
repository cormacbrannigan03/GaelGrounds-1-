import SwiftUI

struct MatchCardView: View {
    let match: MatchSummary

    private var competitionLine: String {
        var parts = [match.competition ?? "Gaelic Games"]
        if let round = match.round { parts.append(round) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationLink(value: MatchRoute(id: match.id)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(competitionLine)
                        .font(.caption.bold())
                        .foregroundStyle(.brandGold)
                        .textCase(.uppercase)
                    Spacer()
                    statusBadge
                }

                HStack {
                    Text(match.homeName).font(.headline).lineLimit(1)
                        .fontWeight(match.winner == .home ? .bold : .regular)
                    Spacer()
                    Text(match.hasScore ? "\(match.homeScore ?? "") – \(match.awayScore ?? "")" : "v")
                        .font(.headline)
                        .foregroundStyle(.brandGreenLight)
                    Spacer()
                    Text(match.awayName).font(.headline).lineLimit(1).multilineTextAlignment(.trailing)
                        .fontWeight(match.winner == .away ? .bold : .regular)
                }

                HStack(spacing: 6) {
                    Text(Formatting.fixtureDateTime(date: match.matchDate, throwInTime: match.throwInTime))
                    if let groundName = match.groundName {
                        Text("· \(groundName)")
                    }
                    Spacer()
                    if match.attendeeCount > 0 {
                        Text("👥 \(match.attendeeCount)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.brandGreenLight.opacity(0.1), in: Capsule())
                            .foregroundStyle(.brandGreenLight)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch match.status {
        case .scheduled:
            Text("Upcoming")
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.brandGold.opacity(0.18), in: Capsule())
                .foregroundStyle(.brandGold)
        case .postponed:
            Text("Postponed")
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.orange.opacity(0.18), in: Capsule())
                .foregroundStyle(.orange)
        case .cancelled:
            Text("Cancelled")
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.secondary.opacity(0.18), in: Capsule())
                .foregroundStyle(.secondary)
        case .completed:
            EmptyView()
        }
    }
}
