import SwiftUI
import Supabase

struct CountyDetailView: View {
    let countyId: UUID

    @State private var county: County?
    @State private var teams: [CountyTeam] = []
    @State private var grounds: [Ground] = []
    @State private var honours: [Honour] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let county {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            CountyBanner(countyName: county.name, height: 26)
                            Text(county.name).font(.title.bold())
                        }
                        Text(county.province.rawValue).foregroundStyle(.secondary)
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.brandGold).frame(width: 4)
                    }

                    section("Intercounty teams") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                            ForEach(teams) { team in
                                NavigationLink(value: TeamRoute(id: team.id)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("\(team.sportCode.icon) \(team.sportCode.label)").font(.headline)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let year = team.foundedYear {
                                            Text("Founded \(year)").font(.caption).foregroundStyle(.secondary)
                                        }
                                        if let manager = team.currentManager {
                                            Text("Manager: \(manager)").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    section("Home grounds") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                            ForEach(grounds) { ground in
                                NavigationLink(value: GroundRoute(id: ground.id)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ground.name).font(.headline)
                                        if let capacity = ground.capacity {
                                            Text("Capacity: \(capacity.formatted())")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !honours.isEmpty {
                        section("Roll of honour") {
                            ForEach(teams) { team in
                                let teamHonours = honours.filter { $0.countyTeamId == team.id }
                                if !teamHonours.isEmpty {
                                    HonoursGroup(team: team, honours: teamHonours)
                                }
                            }
                        }
                    }
                } else {
                    Text("County not found.").foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(county?.name ?? "County")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: GroundRoute.self) { route in
            GroundDetailView(groundId: route.id)
        }
        .navigationDestination(for: TeamRoute.self) { route in
            if let team = teams.first(where: { $0.id == route.id }),
               let county {
                TeamDetailView(team: team, countyName: county.name)
            }
        }
        .task { await load() }
        .gaelGroundsBackground()
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let countyTask: County = Supa.client.from("counties").select().eq("id", value: countyId).single().execute().value
            async let teamsTask: [CountyTeam] = Supa.client.from("county_teams").select().eq("county_id", value: countyId).in("sport_code", values: ["gaelic_football", "hurling"]).execute().value
            async let groundsTask: [Ground] = Supa.client.from("grounds").select().eq("county_id", value: countyId).execute().value

            county = try await countyTask
            teams = try await teamsTask
            grounds = try await groundsTask

            let teamIds = teams.map(\.id)
            if !teamIds.isEmpty {
                honours = try await Supa.client
                    .from("honours")
                    .select()
                    .in("county_team_id", values: teamIds)
                    .order("year", ascending: false)
                    .execute()
                    .value
            }
        } catch {
            print("CountyDetail load failed: \(error)")
        }
    }
}

private struct HonoursGroup: View {
    let team: CountyTeam
    let honours: [Honour]

    private let typeOrder: [HonourType] = [.allIreland, .provincial, .league]

    private func entries(for type: HonourType) -> [(competition: String, years: [Int])] {
        var grouped: [String: [Int]] = [:]
        for h in honours where h.honourType == type {
            grouped[h.competitionName, default: []].append(h.year)
        }
        return grouped.map { (competition: $0.key, years: $0.value.sorted(by: >)) }
            .sorted { $0.years.count > $1.years.count }
    }

    private func sectionTitle(for type: HonourType) -> String {
        switch type {
        case .allIreland: return "All-Ireland"
        case .provincial: return "Provincial"
        case .league: return "League"
        default: return type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(team.sportCode.icon) \(team.sportCode.label)").font(.headline)
            ForEach(typeOrder, id: \.self) { type in
                let entries = entries(for: type)
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sectionTitle(for: type))
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(entries, id: \.competition) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(entry.competition) (\(entry.years.count))").font(.subheadline.bold())
                                    Text(entry.years.map(String.init).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
        }
    }
}
