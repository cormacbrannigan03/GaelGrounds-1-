import SwiftUI

struct MatchCardView: View {
    let match: MatchSummary

    var body: some View {
        NavigationLink(value: MatchRoute(id: match.id)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(match.competition ?? "Gaelic Games")
                        .font(.caption.bold())
                        .foregroundStyle(.brandGold)
                        .textCase(.uppercase)
                    Spacer()
                    if match.isLive {
                        Text("● LIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.brandLive, in: Capsule())
                            .foregroundStyle(.white)
                    } else if match.isUpcoming {
                        Text("Upcoming")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.brandGold.opacity(0.18), in: Capsule())
                            .foregroundStyle(.brandGold)
                    }
                }

                HStack {
                    Text(match.homeName).font(.headline).lineLimit(1)
                    Spacer()
                    Text(match.hasScore ? "\(match.homeScore ?? "") – \(match.awayScore ?? "")" : "v")
                        .font(.headline)
                        .foregroundStyle(.brandGreenLight)
                    Spacer()
                    Text(match.awayName).font(.headline).lineLimit(1).multilineTextAlignment(.trailing)
                }

                HStack(spacing: 6) {
                    Text(Formatting.matchDate(match.playedAt))
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
}
