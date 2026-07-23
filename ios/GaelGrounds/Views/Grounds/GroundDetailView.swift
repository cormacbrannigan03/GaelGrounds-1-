import SwiftUI
internal import PostgREST
import Supabase

struct GroundDetailView: View {
    let groundId: UUID

    @State private var ground: Ground?
    @State private var countyName: String?
    @State private var countyGrounds: [Ground] = []
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
                            HStack(spacing: 6) {
                                CountyBanner(countyName: countyName)
                                Text(countyName).foregroundStyle(.secondary)
                            }
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

                    if !countyGrounds.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Alternate Grounds")
                                .font(.title3.bold())
                            ForEach(countyGrounds) { other in
                                NavigationLink(value: GroundRoute(id: other.id)) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.brandGold)
                                        Text(other.name)
                                            .font(.body)
                                        Spacer()
                                        if let cap = other.capacity {
                                            Text(cap.formatted())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Text("Ground not found.").foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Ground")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .gaelGroundsBackground()
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
            async let countyTask: County = Supa.client.from("counties").select().eq("id", value: g.countyId).single().execute().value
            async let othersTask: [Ground] = g.isPrimary ? Supa.client.from("grounds").select()
                .eq("county_id", value: g.countyId)
                .eq("is_primary", value: false)
                .order("name")
                .execute().value : []
            let county = try await countyTask
            countyName = county.name
            countyGrounds = try await othersTask
        } catch {
            print("GroundDetail load failed: \(error)")
        }
    }
}
