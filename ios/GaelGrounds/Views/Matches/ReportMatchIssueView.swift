import SwiftUI

struct ReportMatchIssueView: View {
    let matchId: UUID
    var onSubmitted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthViewModel

    private enum IssueType: String, CaseIterable, Identifiable {
        case venue, date, time, score

        var id: String { rawValue }

        var label: String {
            switch self {
            case .venue: return "Venue"
            case .date: return "Date"
            case .time: return "Time"
            case .score: return "Score"
            }
        }
    }

    @State private var selectedIssues: Set<IssueType> = []
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool { !selectedIssues.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(IssueType.allCases) { issue in
                        Button {
                            toggle(issue)
                        } label: {
                            HStack {
                                Text(issue.label).foregroundStyle(.primary)
                                Spacer()
                                if selectedIssues.contains(issue) {
                                    Image(systemName: "checkmark").foregroundStyle(.brandGreenLight)
                                }
                            }
                        }
                    }
                } header: {
                    Text("What's wrong?")
                } footer: {
                    Text("Select everything that looks incorrect — you can pick more than one.")
                }

                Section {
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                } header: {
                    Text("Tell us more (optional)")
                } footer: {
                    Text("Any extra detail helps — the correct venue, date, time, or score, for example.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Report an issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") {
                            Task { await submit() }
                        }
                        .bold()
                        .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    private func toggle(_ issue: IssueType) {
        if selectedIssues.contains(issue) {
            selectedIssues.remove(issue)
        } else {
            selectedIssues.insert(issue)
        }
    }

    private func submit() async {
        guard let userId = auth.userId else {
            errorMessage = "You must be signed in to report an issue."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await MatchService.submitReport(
                MatchReportInsert(
                    matchId: matchId,
                    userId: userId,
                    issueTypes: selectedIssues.map(\.rawValue),
                    details: details.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            )
            onSubmitted?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
