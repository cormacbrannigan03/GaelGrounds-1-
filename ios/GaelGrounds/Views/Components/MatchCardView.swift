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
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(.background.secondary)
                colourWash.clipShape(RoundedRectangle(cornerRadius: 14))

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
            }
        }
        .buttonStyle(.plain)
    }

    /// Each side's primary colour sits at its own edge, fades through that
    /// county's secondary colour, and is fully transparent by the card's
    /// midpoint -- so the card's own background shows through in the
    /// middle rather than a hardcoded white, which is what keeps this
    /// looking right in dark mode too.
    private var colourWash: some View {
        ZStack {
            wash(match.homeColours, startPoint: .leading, endPoint: .trailing)
            wash(match.awayColours, startPoint: .trailing, endPoint: .leading)
        }
    }

    private func wash(_ colours: CountyColours?, startPoint: UnitPoint, endPoint: UnitPoint) -> some View {
        guard let colours, let primary = Color(hex: colours.primary), let secondary = Color(hex: colours.secondary) else {
            return AnyView(Color.clear)
        }
        let gradient = Gradient(stops: [
            .init(color: primary.opacity(0.34), location: 0),
            .init(color: secondary.opacity(0.20), location: 0.30),
            .init(color: secondary.opacity(0), location: 0.55)
        ])
        return AnyView(LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint))
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
