import SwiftUI

struct MatchesView: View {
    private enum Tab { case upcoming, fixtures, results }

    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var premium: PremiumStore

    @State private var matches: [MatchSummary] = []
    @State private var personalMatches: [UserPersonalMatch] = []
    @State private var selectedSport: SportCode = .gaelicFootball
    @State private var tab: Tab = .upcoming
    @State private var search = ""
    @State private var isLoading = true
    @State private var expandedYears: Set<Int> = []
    @State private var expandedMonths: Set<String> = []
    @State private var showingAddMatch = false
    @State private var showingPaywall = false
    @State private var showingFilters = false
    @State private var selectedCounty = ""
    @State private var selectedCompetition = ""
    @State private var selectedVenue = ""

    // MARK: - Filtered helpers

    private var sportFiltered: [MatchSummary] {
        matches.filter { $0.sportCode == selectedSport }
    }

    private var searchFiltered: [MatchSummary] {
        let q = normalizedForSearch(search)
        guard !q.isEmpty else { return sportFiltered }
        return sportFiltered.filter { m in
            normalizedForSearch(m.homeName).contains(q)
                || normalizedForSearch(m.awayName).contains(q)
                || normalizedForSearch(m.competition ?? "").contains(q)
                || normalizedForSearch(m.groundName ?? "").contains(q)
                || normalizedForSearch(m.round ?? "").contains(q)
                || m.playedAt.map { String(Calendar.current.component(.year, from: $0)).contains(q) } == true
        }
    }

    private var filteredMatches: [MatchSummary] {
        searchFiltered.filter { match in
            matchesSelection(selectedCounty, in: [match.homeName, match.awayName])
                && matchesSelection(selectedCompetition, in: [match.competition])
                && matchesSelection(selectedVenue, in: [match.groundName])
        }
    }

    private var filteredPersonalMatches: [UserPersonalMatch] {
        let q = normalizedForSearch(search)
        return personalMatches.filter { m in
            let matchesSearch = q.isEmpty
                || normalizedForSearch(m.homeTeam).contains(q)
                || normalizedForSearch(m.awayTeam).contains(q)
                || normalizedForSearch(m.competition ?? "").contains(q)
                || normalizedForSearch(m.venue ?? "").contains(q)
                || normalizedForSearch(m.round ?? "").contains(q)
            return matchesSearch
                && matchesSelection(selectedCounty, in: [m.homeTeam, m.awayTeam])
                && matchesSelection(selectedCompetition, in: [m.competition])
                && matchesSelection(selectedVenue, in: [m.venue])
        }
    }

    private var upcomingList: [MatchSummary] {
        filteredMatches.filter { $0.isUpcoming || $0.isLive }
            .sorted { ($0.playedAt ?? .distantFuture) < ($1.playedAt ?? .distantFuture) }
    }

    private var fixturesList: [MatchSummary] {
        filteredMatches.filter { $0.isUpcoming || $0.isLive }
            .sorted { ($0.playedAt ?? .distantFuture) < ($1.playedAt ?? .distantFuture) }
    }

    private var yearGroups: [(year: Int, months: [(month: Int, matches: [MatchSummary])])] {
        let past = filteredMatches.filter(\.isPast)
        let cal = Calendar.current
        var grouped: [Int: [Int: [MatchSummary]]] = [:]
        for m in past {
            guard let playedAt = m.playedAt else { continue }
            let y = cal.component(.year, from: playedAt)
            let mo = cal.component(.month, from: playedAt)
            grouped[y, default: [:]][mo, default: []].append(m)
        }
        return grouped
            .map { year, months in
                (year: year,
                 months: months
                    .map { month, list in
                        (month: month, matches: list.sorted {
                            ($0.playedAt ?? .distantPast) > ($1.playedAt ?? .distantPast)
                        })
                    }
                    .sorted { $0.month > $1.month })
            }
            .sorted { $0.year > $1.year }
    }

    private var undatedResults: [MatchSummary] {
        filteredMatches
            .filter { $0.playedAt == nil }
            .sorted {
                ($0.competition ?? "", $0.homeName, $0.awayName)
                    < ($1.competition ?? "", $1.homeName, $1.awayName)
            }
    }

    private var countyOptions: [String] {
        uniqueSorted(
            sportFiltered.flatMap { [$0.homeName, $0.awayName] }
                + personalMatches.flatMap { [$0.homeTeam, $0.awayTeam] }
        )
    }

    private var competitionOptions: [String] {
        uniqueSorted(sportFiltered.compactMap(\.competition) + personalMatches.compactMap(\.competition))
    }

    private var venueOptions: [String] {
        uniqueSorted(sportFiltered.compactMap(\.groundName) + personalMatches.compactMap(\.venue))
    }

    private var activeFilterCount: Int {
        [selectedCounty, selectedCompetition, selectedVenue].filter { !$0.isEmpty }.count
    }

    private var hasQueryOrFilters: Bool {
        !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || activeFilterCount > 0
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                    TextField("Search by team, competition, ground or year…", text: $search)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        showingFilters = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .frame(width: 38, height: 38)

                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(.brandGold, in: Circle())
                                    .offset(x: 3, y: -3)
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(activeFilterCount > 0 ? .brandGreenLight : .secondary)
                    .accessibilityLabel("Filter matches")
                    .accessibilityValue(activeFilterCount > 0 ? "\(activeFilterCount) active" : "No active filters")
                    }

                    Picker("Sport", selection: $selectedSport) {
                        Text("Football").tag(SportCode.gaelicFootball)
                        Text("Hurling").tag(SportCode.hurling)
                    }
                    .pickerStyle(.segmented)

                    Picker("Tab", selection: $tab) {
                        Text("Upcoming").tag(Tab.upcoming)
                        Text("Fixtures").tag(Tab.fixtures)
                        Text("Results").tag(Tab.results)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(12)
                .gaelCard(cornerRadius: 16)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    switch tab {
                    case .upcoming:
                        upcomingContent
                    case .fixtures:
                        fixturesContent
                    case .results:
                        resultsContent
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Fixtures & results")
        .navigationDestination(for: MatchRoute.self) { route in
            MatchDetailView(matchId: route.id, isFinalOnLoad: route.isFinal, winnerNameOnLoad: route.winnerName)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await tapAddMatch() }
                } label: {
                    Label("Add Match", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddMatch) {
            AddMatchView {
                Task { await load() }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView(reason: "You've reached the 10-match free limit. Upgrade to log more.")
        }
        .sheet(isPresented: $showingFilters) {
            MatchFiltersView(
                selectedCounty: $selectedCounty,
                selectedCompetition: $selectedCompetition,
                selectedVenue: $selectedVenue,
                countyOptions: countyOptions,
                competitionOptions: competitionOptions,
                venueOptions: venueOptions
            )
        }
        .task { await load() }
        .refreshable { await load() }
        .gaelGroundsBackground()
    }

    // MARK: - Tab content

    @ViewBuilder
    private var upcomingContent: some View {
        if upcomingList.isEmpty {
            Text(hasQueryOrFilters ? "No matches found." : "No upcoming fixtures.")
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 10) {
                ForEach(upcomingList) { match in
                    MatchCardView(match: match)
                }
            }
        }
    }

    @ViewBuilder
    private var fixturesContent: some View {
        if fixturesList.isEmpty {
            Text(hasQueryOrFilters ? "No matches found." : "No fixtures found.")
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 10) {
                ForEach(fixturesList) { match in
                    MatchCardView(match: match)
                }
            }
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        let hasPersonal = !filteredPersonalMatches.isEmpty
        let hasOfficial = !yearGroups.isEmpty || !undatedResults.isEmpty

        if !hasPersonal && !hasOfficial {
            ContentUnavailableView(
                hasQueryOrFilters ? "No matches found" : "No results yet",
                systemImage: "sportscourt",
                description: Text(hasQueryOrFilters ? "Try a different search or filter." : "Check back once games have been played.")
            )
            .padding(.top, 40)
        } else {
            VStack(spacing: 12) {
                if hasPersonal {
                    MyMatchesSection(matches: filteredPersonalMatches) { match in
                        Task {
                            try? await MatchService.deletePersonalMatch(match.id)
                            await load()
                        }
                    }
                }
                ForEach(yearGroups, id: \.year) { entry in
                    YearSection(
                        year: entry.year,
                        monthEntries: entry.months,
                        isExpanded: yearBinding(entry.year),
                        expandedMonths: $expandedMonths
                    )
                }
                if !undatedResults.isEmpty {
                    UndatedResultsSection(matches: undatedResults)
                }
            }
        }
    }

    // MARK: - Helpers

    private func yearBinding(_ year: Int) -> Binding<Bool> {
        Binding(
            get: { expandedYears.contains(year) },
            set: { if $0 { expandedYears.insert(year) } else { expandedYears.remove(year) } }
        )
    }

    private func tapAddMatch() async {
        guard let userId = auth.userId else { return }
        if await MatchService.canLogAnotherMatch(userId: userId, isPremium: premium.isPremium) {
            showingAddMatch = true
        } else {
            showingPaywall = true
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows = try await MatchService.fetchAll()
            matches = try await MatchService.resolveSummaries(rows)
        } catch {
            print("Matches load failed: \(error)")
        }
        if let userId = auth.userId {
            personalMatches = (try? await MatchService.fetchPersonalMatches(userId: userId)) ?? []
        }
        setDefaultExpansion()
    }

    private func setDefaultExpansion() {
        let cal = Calendar.current
        let past = sportFiltered.filter(\.isPast)
        let datedPast = past.compactMap { match -> (MatchSummary, Date)? in
            guard let playedAt = match.playedAt else { return nil }
            return (match, playedAt)
        }
        guard let mostRecentYear = datedPast.map({ cal.component(.year, from: $0.1) }).max() else { return }
        expandedYears = [mostRecentYear]
        let mostRecentMonth = datedPast
            .filter { cal.component(.year, from: $0.1) == mostRecentYear }
            .map { cal.component(.month, from: $0.1) }
            .max()
        if let month = mostRecentMonth {
            expandedMonths = ["\(mostRecentYear)-\(month)"]
        }
    }

    // Folds accents (e.g. "Páirc" -> "pairc") and case before comparing, so
    // searching without fada/síneadh fada on Irish-language ground and
    // competition names -- which most people typing on a phone won't --
    // still matches. Plain .lowercased() alone leaves "á" != "a".
    private func normalizedForSearch(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func matchesSelection(_ selection: String, in values: [String?]) -> Bool {
        guard !selection.isEmpty else { return true }
        return values.contains { $0 == selection }
    }

    private func uniqueSorted(_ values: [String]) -> [String] {
        Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

// MARK: - Filters

private struct MatchFiltersView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedCounty: String
    @Binding var selectedCompetition: String
    @Binding var selectedVenue: String

    let countyOptions: [String]
    let competitionOptions: [String]
    let venueOptions: [String]

    private var hasActiveFilters: Bool {
        !selectedCounty.isEmpty || !selectedCompetition.isEmpty || !selectedVenue.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("County") {
                    Picker("County", selection: $selectedCounty) {
                        Text("Any county").tag("")
                        ForEach(countyOptions, id: \.self) { county in
                            Text(county).tag(county)
                        }
                    }
                }

                Section("Competition") {
                    Picker("Competition", selection: $selectedCompetition) {
                        Text("Any competition").tag("")
                        ForEach(competitionOptions, id: \.self) { competition in
                            Text(competition).tag(competition)
                        }
                    }
                }

                Section("Venue") {
                    Picker("Venue", selection: $selectedVenue) {
                        Text("Any venue").tag("")
                        ForEach(venueOptions, id: \.self) { venue in
                            Text(venue).tag(venue)
                        }
                    }
                }
            }
            .navigationTitle("Filter Matches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedCounty = ""
                        selectedCompetition = ""
                        selectedVenue = ""
                    }
                    .disabled(!hasActiveFilters)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Results without a recorded date

private struct UndatedResultsSection: View {
    let matches: [MatchSummary]

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 10) {
                ForEach(matches) { match in
                    MatchCardView(match: match)
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.secondary.opacity(0.16))
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 34, height: 34)

                Text("Date unavailable")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(matches.count) match\(matches.count == 1 ? "" : "es")")
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .tint(.brandGreenLight)
        .padding()
        .gaelCard(cornerRadius: 16)
    }
}

// MARK: - My Matches section

private struct MyMatchesSection: View {
    let matches: [UserPersonalMatch]
    let onDelete: (UserPersonalMatch) -> Void

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                ForEach(matches) { match in
                    PersonalMatchCard(match: match) {
                        onDelete(match)
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(
                        LinearGradient(colors: [.brandGreenLight, .brandGreen], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    Image(systemName: "person.fill.badge.plus")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                Text("My Matches")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(matches.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.brandGreenLight.opacity(0.14), in: Capsule())
                    .foregroundStyle(.brandGreenLight)
            }
            .padding(.vertical, 4)
        }
        .tint(.brandGreenLight)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.brandSurfaceRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.brandGreenLight.opacity(0.14), .clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.brandBorder, lineWidth: 1)
                }
                .shadow(color: Color.brandGreen.opacity(0.08), radius: 8, y: 3)
        }
    }
}

// MARK: - Personal match card

private struct PersonalMatchCard: View {
    let match: UserPersonalMatch
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(match.competition ?? "Personal Match")
                        .font(.caption.bold())
                        .foregroundStyle(.brandGold)
                        .textCase(.uppercase)
                    if let round = match.round {
                        Text(round)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "person.badge.plus")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Text(match.homeTeam)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(match.hasScore
                     ? "\(match.homeScore ?? "") – \(match.awayScore ?? "")"
                     : "v")
                    .font(.headline)
                    .foregroundStyle(.brandGreenLight)
                Spacer()
                Text(match.awayTeam)
                    .font(.headline)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
            }

            HStack(spacing: 6) {
                Text(Formatting.matchDate(match.playedAt))
                if let venue = match.venue {
                    Text("· \(venue)")
                }
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .gaelInsetCard(cornerRadius: 12)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete match", systemImage: "trash")
            }
        }
    }
}

// MARK: - Year section

private struct YearSection: View {
    let year: Int
    let monthEntries: [(month: Int, matches: [MatchSummary])]
    @Binding var isExpanded: Bool
    @Binding var expandedMonths: Set<String>

    private var totalCount: Int { monthEntries.reduce(0) { $0 + $1.matches.count } }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(monthEntries, id: \.month) { entry in
                    MonthSection(
                        month: entry.month,
                        matches: entry.matches,
                        isExpanded: monthBinding(entry.month)
                    )
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(
                        LinearGradient(colors: [.brandGold, .brandGold.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    Image(systemName: "trophy.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                Text(String(year))
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(totalCount) match\(totalCount == 1 ? "" : "es")")
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.brandGreenLight.opacity(0.14), in: Capsule())
                    .foregroundStyle(.brandGreenLight)
            }
            .padding(.vertical, 4)
        }
        .tint(.brandGreenLight)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.brandSurfaceRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.brandGold.opacity(0.12), .clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.brandBorder, lineWidth: 1)
                }
                .shadow(color: Color.brandGreen.opacity(0.08), radius: 8, y: 3)
        }
    }

    private func monthBinding(_ month: Int) -> Binding<Bool> {
        let key = "\(year)-\(month)"
        return Binding(
            get: { expandedMonths.contains(key) },
            set: { if $0 { expandedMonths.insert(key) } else { expandedMonths.remove(key) } }
        )
    }
}

// MARK: - Month section

private struct MonthSection: View {
    let month: Int
    let matches: [MatchSummary]
    @Binding var isExpanded: Bool

    private var monthName: String { Calendar.current.monthSymbols[month - 1] }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 10) {
                ForEach(matches) { match in
                    MatchCardView(match: match)
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.caption.bold())
                    .foregroundStyle(.brandGreenLight)
                    .frame(width: 24, height: 24)
                    .background(Color.brandGreenLight.opacity(0.14), in: Circle())

                Text(monthName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(matches.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.brandGreenLight.opacity(0.12), in: Capsule())
                    .foregroundStyle(.brandGreenLight)
            }
            .padding(.vertical, 2)
        }
        .tint(.brandGreenLight)
        .padding(10)
        .gaelInsetCard(cornerRadius: 12)
    }
}
