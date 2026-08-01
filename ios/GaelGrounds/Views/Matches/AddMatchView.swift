import SwiftUI

struct AddMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var premium: PremiumStore

    @State private var homeTeam = ""
    @State private var awayTeam = ""
    @State private var competition = ""
    @State private var round = ""
    @State private var venue = ""
    @State private var date = Date()
    @State private var homeScore = ""
    @State private var awayScore = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingPaywall = false
    @State private var paywallReason: String?

    var onSaved: (() -> Void)?

    private var canSave: Bool {
        !homeTeam.trimmingCharacters(in: .whitespaces).isEmpty &&
        !awayTeam.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var minimumDate: Date {
        premium.isPremium ? .distantPast : MatchService.freeHistoryCutoff
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Teams") {
                    TextField("Home team", text: $homeTeam)
                        .autocorrectionDisabled()
                    TextField("Away team", text: $awayTeam)
                        .autocorrectionDisabled()
                }

                Section {
                    TextField("Competition (e.g. All-Ireland SFC)", text: $competition)
                    TextField("Round (e.g. Quarter-Final)", text: $round)
                    TextField("Venue", text: $venue)
                        .autocorrectionDisabled()
                    DatePicker(
                        "Date & time",
                        selection: $date,
                        in: minimumDate...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } header: {
                    Text("Match details")
                } footer: {
                    if !premium.isPremium {
                        Text("Free accounts can log matches from 2019 onward. Premium unlocks any year.")
                    }
                }

                Section {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(homeTeam.isEmpty ? "Home" : homeTeam)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            TextField("0-00", text: $homeScore)
                                .keyboardType(.numbersAndPunctuation)
                                .font(.title3.bold())
                        }

                        Text("–")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(awayTeam.isEmpty ? "Away" : awayTeam)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            TextField("0-00", text: $awayScore)
                                .keyboardType(.numbersAndPunctuation)
                                .font(.title3.bold())
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Score (optional)")
                } footer: {
                    Text("Goals–points format, e.g. 1-14")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .bold()
                        .disabled(!canSave)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView(reason: paywallReason)
        }
    }

    private func save() async {
        guard let userId = auth.userId else {
            errorMessage = "You must be signed in to add a match."
            return
        }

        if !premium.isPremium, !MatchService.isDateAllowedForFreeTier(date) {
            paywallReason = "Matches before 2019 require Premium."
            showingPaywall = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        guard await MatchService.canLogAnotherMatch(userId: userId, isPremium: premium.isPremium) else {
            paywallReason = "You've reached the 10-match free limit. Upgrade to log more."
            showingPaywall = true
            return
        }

        let hs = homeScore.trimmingCharacters(in: .whitespaces)
        let as_ = awayScore.trimmingCharacters(in: .whitespaces)

        let insert = UserPersonalMatchInsert(
            userId: userId,
            homeTeam: homeTeam.trimmingCharacters(in: .whitespaces),
            awayTeam: awayTeam.trimmingCharacters(in: .whitespaces),
            competition: competition.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            round: round.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            venue: venue.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            playedAt: date,
            homeScore: hs.nilIfEmpty,
            awayScore: as_.nilIfEmpty
        )

        do {
            try await MatchService.insertPersonalMatch(insert)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
