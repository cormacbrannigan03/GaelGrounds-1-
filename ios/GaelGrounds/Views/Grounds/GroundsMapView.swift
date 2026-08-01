import MapKit
import SwiftUI

struct GroundsMapView: View {
    let grounds: [GroundSummary]

    private static let irelandRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 53.5, longitude: -8.0),
        latitudinalMeters: 650_000,
        longitudinalMeters: 550_000
    )

    @Environment(\.dismiss) private var dismiss

    var visitedCount: Int { grounds.filter(\.visited).count }

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(Self.irelandRegion)) {
                ForEach(grounds) { ground in
                    Annotation(
                        ground.visited ? ground.name : "",
                        coordinate: CLLocationCoordinate2D(
                            latitude: ground.latitude,
                            longitude: ground.longitude
                        )
                    ) {
                        GroundMapPin(
                            name: ground.name,
                            visited: ground.visited,
                            isPrimary: ground.isPrimary
                        )
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .navigationTitle("Grounds Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Text(visitedCount == 0
                         ? "Check in at grounds to light them up"
                         : "\(visitedCount) of \(grounds.count) grounds visited")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct GroundMapPin: View {
    let name: String
    let visited: Bool
    let isPrimary: Bool

    var body: some View {
        let diameter: CGFloat = isPrimary ? 16 : 6

        Circle()
            .fill(visited ? Color.green : Color(.systemGray3))
            .frame(width: diameter, height: diameter)
            .overlay {
                if isPrimary {
                    Circle().stroke(.black, lineWidth: 2)
                }
            }
            .shadow(
                color: visited ? .green.opacity(0.55) : .clear,
                radius: isPrimary ? 5 : 2
            )
    }
}

struct IrelandMapIcon: View {
    private static let irelandRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 53.5, longitude: -8.0),
        latitudinalMeters: 650_000,
        longitudinalMeters: 550_000
    )

    var body: some View {
        Map(initialPosition: .region(Self.irelandRegion), interactionModes: [])
            .frame(width: 30, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .allowsHitTesting(false)
    }
}
