import SwiftUI

struct GroundCardView: View {
    let ground: GroundSummary
    var alternates: [AlternateGround] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                                .foregroundStyle(.brandGreenLight)
                        }
                    }
                    Text(ground.countyName).font(.subheadline).foregroundStyle(.secondary)
                    if let capacity = ground.capacity {
                        Text("Capacity: \(capacity.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if !alternates.isEmpty {
                Divider().padding(.vertical, 2)
                Text("Also in \(ground.countyName):")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(alternates) { alt in
                        NavigationLink(value: GroundRoute(id: alt.id)) {
                            HStack(spacing: 4) {
                                Text(alt.name).font(.caption)
                                if alt.visited {
                                    Text("✓").font(.caption2.bold()).foregroundStyle(.brandGreenLight)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .gaelCard(cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ground.visited ? Color.brandGreenLight : .clear, lineWidth: 1.5)
        )
    }
}
