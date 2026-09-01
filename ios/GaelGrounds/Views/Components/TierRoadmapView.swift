import SwiftUI

/// Visual version of the 10/25/50 bronze/silver/gold thresholds in
/// AchievementTier.forHomeMatchCount -- mirrors TierRoadmap.tsx on web.
struct TierRoadmapView: View {
    let count: Int

    private let stops: [(tier: AchievementTier, threshold: Int)] = [
        (.bronze, 10), (.silver, 25), (.gold, 50),
    ]

    private var fillFraction: Double {
        Double(min(count, 50)) / 50
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5)).frame(height: 6)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.72, green: 0.45, blue: 0.20), Color(red: 0.55, green: 0.60, blue: 0.66), .brandGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * fillFraction, height: 6)

                ForEach(stops, id: \.threshold) { stop in
                    let reached = count >= stop.threshold
                    Circle()
                        .fill(reached ? stop.tier.tint : Color(.systemBackground))
                        .overlay(Circle().stroke(reached ? stop.tier.tint : Color(.systemGray3), lineWidth: 2))
                        .frame(width: 10, height: 10)
                        .position(x: geo.size.width * (Double(stop.threshold) / 50), y: 3)
                }
            }
        }
        .frame(height: 10)
    }
}
