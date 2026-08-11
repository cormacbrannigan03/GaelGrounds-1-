import SwiftUI
import Supabase

struct CountiesView: View {
    @EnvironmentObject private var supportedCounty: SupportedCountyStore

    @State private var counties: [County] = []
    @State private var isLoading = true

    private static let provinceOrder: [Province] = [.leinster, .munster, .connacht, .ulster]
    private static let otherCountyNames: Set<String> = [
        "Fingal", "Warwickshire", "Lancashire", "South Down"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("All 32 counties").font(.title2.bold())
                Text("Every county competing at intercounty level, across Gaelic football, hurling, camogie and ladies' football.")
                    .foregroundStyle(.secondary)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    ForEach(Self.provinceOrder, id: \.self) { province in
                        let inProvince = counties.filter {
                            $0.province == province &&
                            !Self.otherCountyNames.contains($0.name)
                        }
                        if !inProvince.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(province.rawValue).font(.headline)
                                FlowChips(counties: inProvince)
                            }
                        }
                    }

                    let otherCounties = counties.filter {
                        Self.otherCountyNames.contains($0.name)
                    }
                    if !otherCounties.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Others").font(.headline)
                            FlowChips(counties: otherCounties)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Counties")
        .navigationDestination(for: CountyRoute.self) { route in
            CountyDetailView(countyId: route.id)
        }
        .task { await load() }
        .refreshable { await load() }
        .countyBackground(supportedCounty.countyName)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            counties = try await Supa.client.from("counties").select().order("name").execute().value
        } catch {
            print("Counties load failed: \(error)")
        }
    }
}

/// Simple wrapping chip layout (LazyVGrid with an adaptive minimum reads
/// close enough to a flow-layout for a list of short county names).
private struct FlowChips: View {
    let counties: [County]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(counties) { county in
                NavigationLink(value: CountyRoute(id: county.id)) {
                    HStack(spacing: 6) {
                        CountyBanner(countyName: county.name)
                        Text(county.name)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.background.secondary, in: Capsule())
                    .overlay(Capsule().stroke(.secondary.opacity(0.3), lineWidth: 1))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
