import SwiftUI

struct GroundCardView: View {
    let ground: GroundSummary

    var body: some View {
        NavigationLink(value: GroundRoute(id: ground.id)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(ground.name).font(.headline)
                    Spacer()
                    if ground.visited {
                        Text("✓ Visited")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.brandGreenLight.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.brandGreenLight)
                    }
                }
                HStack(spacing: 6) {
                    CountyBanner(countyName: ground.countyName)
                    Text(ground.countyName).font(.subheadline).foregroundStyle(.secondary)
                }
                if let capacity = ground.capacity {
                    Text("Capacity: \(capacity.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ground.visited ? Color.brandGreenLight : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
