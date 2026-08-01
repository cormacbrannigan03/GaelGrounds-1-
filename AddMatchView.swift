import SwiftUI

struct AddMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthViewModel

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

    var onSaved: (() -> Void)?

    private var canSave: Bool {
        !homeTeam.trimmingCharacters(in: .whitespaces).isEmpty &&
        !awayTeam.trimmingCharacters(in: .whitespaces).isEmpty
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

                Section("Match details") {
                    TextField("Competition (e.g. All-Ireland SFC)", text: $competition)
                    TextField("Round (e.g. Quarter-Final)", text: $round)
                    TextField("Venue", text: $venue)
                        .autocorrectionDisabled()
                    DatePicker("Date & time", selection: $date, displayedComponents: [.date, .hourAndMinute])
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
    }

    private func save() async {
        guard let userId = auth.userId else {
            errorMessage = "You must be signed in to add a match."
            return
        }
        isSaving = true
        defer { isSaving = false }

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
