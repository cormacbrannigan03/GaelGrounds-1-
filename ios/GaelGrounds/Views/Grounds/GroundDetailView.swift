import SwiftUI
import PostgREST
import Supabase

struct GroundDetailView: View {
    let groundId: UUID

    @State private var ground: Ground?
    @State private var countyName: String?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let ground {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ground.name).font(.title2.bold())
                        if let countyName {
                            Text(countyName).foregroundStyle(.secondary)
                        }
                        if let capacity = ground.capacity {
                            Text("Capacity: \(capacity.formatted())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Link("View on map →", destination: mapURL(for: ground))
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.brandGold).frame(width: 4)
                    }

                    GroundCheckInPanel(groundId: ground.id)
                } else {
                    Text("Ground not found.").foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Ground")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .countyBackground(countyName)
    }

    private func mapURL(for ground: Ground) -> URL {
        let name = ground.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ground.name
        return URL(string: "https://maps.apple.com/?ll=\(ground.latitude),\(ground.longitude)&q=\(name)")!
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let g: Ground = try await Supa.client.from("grounds").select().eq("id", value: groundId).single().execute().value
            ground = g
            let county: County = try await Supa.client.from("counties").select().eq("id", value: g.countyId).single().execute().value
            countyName = county.name
        } catch {
            print("GroundDetail load failed: \(error)")
        }
    }
}
