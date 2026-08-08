import MapKit
import SwiftUI
import Supabase

struct GroundsView: View {
    @EnvironmentObject private var auth: AuthViewModel

    @State private var grounds: [GroundSummary] = []
    @State private var mapGrounds: [GroundSummary] = []
    @State private var search = ""
    @State private var isLoading = true
    @State private var showMap = false
    @State private var supportedCountyName: String?

    private var filtered: [GroundSummary] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return grounds }
        return grounds.filter { $0.name.lowercased().contains(q) || $0.countyName.lowercased().contains(q) }
    }

    private var visitedCount: Int { grounds.filter(\.visited).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    visitedCount > 0
                        ? "You've visited \(visitedCount) of \(grounds.count) grounds."
                        : "Browse every intercounty ground and check in when you visit."
                )
                .foregroundStyle(.secondary)

                TextField("Search grounds or counties…", text: $search)
                    .textFieldStyle(.roundedBorder)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                        ForEach(filtered) { ground in
                            GroundCardView(ground: ground)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Grounds")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showMap = true } label: {
                    IrelandMapIcon()
                }
            }
        }
        .sheet(isPresented: $showMap) {
            GroundsMapView(grounds: mapGrounds)
        }
        .navigationDestination(for: GroundRoute.self) { route in
            GroundDetailView(groundId: route.id)
        }
        .task { await load() }
        .refreshable { await load() }
        .countyBackground(supportedCountyName)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let groundRows: [Ground] = try await Supa.client.from("grounds").select().order("name").execute().value
            let counties: [County] = try await Supa.client.from("counties").select().execute().value
            let countyNameById = Dictionary(uniqueKeysWithValues: counties.map { ($0.id, $0.name) })

            var visitedIds = Set<UUID>()
            if let userId = auth.userId {
                let visits: [UserVisit] = try await Supa.client
                    .from("user_visits").select().eq("user_id", value: userId).execute().value
                visitedIds = Set(visits.map(\.groundId))
                supportedCountyName = await SupportedCountyService.fetchName(userId: userId)
            }

            mapGrounds = groundRows.map { g in
                GroundSummary(
                    id: g.id,
                    name: g.name,
                    countyName: countyNameById[g.countyId] ?? "",
                    capacity: g.capacity,
                    visited: visitedIds.contains(g.id),
                    latitude: g.latitude,
                    longitude: g.longitude,
                    isPrimary: g.isPrimary
                )
            }
            grounds = mapGrounds.filter(\.isPrimary)
        } catch {
            print("Grounds load failed: \(error)")
        }
    }
}
