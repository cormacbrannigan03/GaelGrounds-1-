import SwiftUI

struct MatchCardView: View {
    let match: MatchSummary

    private var homeColors: (Color, Color) { CountyPalette.colours(for: match.homeName) }
    private var awayColors: (Color, Color) { CountyPalette.colours(for: match.awayName) }

    var body: some View {
        NavigationLink(value: MatchRoute(id: match.id, isFinal: match.isFinal, winnerName: match.winnerName)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(match.competition ?? "Gaelic Games")
                            .font(.caption.bold())
                            .foregroundStyle(.brandGold)
                            .textCase(.uppercase)
                        if let round = match.round {
                            Text(round)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
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
                    CountyBanner(countyName: match.homeName)
                    Text(match.homeName).font(.headline).lineLimit(1)
                    Spacer()
                    Text(match.hasScore ? "\(match.homeScore ?? "") – \(match.awayScore ?? "")" : "v")
                        .font(.headline)
                        .foregroundStyle(.brandGreenLight)
                    Spacer()
                    Text(match.awayName).font(.headline).lineLimit(1).multilineTextAlignment(.trailing)
                    CountyBanner(countyName: match.awayName)
                }

                HStack(spacing: 6) {
                    Text(match.playedAt.map(Formatting.matchDate) ?? "Date unavailable")
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
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: homeColors.0.opacity(0.55), location: 0.0),
                                        .init(color: homeColors.1.opacity(0.30), location: 0.22),
                                        .init(color: .clear,                     location: 0.45),
                                        .init(color: .clear,                     location: 0.55),
                                        .init(color: awayColors.1.opacity(0.30), location: 0.78),
                                        .init(color: awayColors.0.opacity(0.55), location: 1.0),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    }
                    .shadow(color: Color.brandGreen.opacity(0.07), radius: 7, y: 3)
            }
        }
        .buttonStyle(.plain)
    }
}
