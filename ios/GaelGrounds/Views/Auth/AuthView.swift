import SwiftUI
import Supabase

struct AuthView: View {
    @EnvironmentObject private var auth: AuthViewModel

    private enum Mode { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var counties: [County] = []
    @State private var supportedCountyId: UUID?
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isBusy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode == .signIn ? "Welcome back" : "Create your account")
                        .font(.title2.bold())
                    Text("Track every ground and match you attend, across all 32 counties.")
                        .foregroundStyle(.secondary)
                }

                Picker("Mode", selection: $mode) {
                    Text("Sign in").tag(Mode.signIn)
                    Text("Sign up").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)

                if mode == .signUp {
                    TextField("Display name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)

                    Picker("Supported county", selection: $supportedCountyId) {
                        Text("Select your county").tag(nil as UUID?)
                        ForEach(counties) { county in
                            Text(county.name).tag(county.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
                if let infoMessage {
                    Text(infoMessage).foregroundStyle(Color.brandGreenLight).font(.footnote)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isBusy {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(mode == .signIn ? "Sign in" : "Create account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
                .controlSize(.large)
                .disabled(
                    isBusy ||
                    email.isEmpty ||
                    password.count < 6 ||
                    (mode == .signUp && supportedCountyId == nil)
                )
            }
            .padding()
        }
        .navigationTitle("GaelGrounds")
        .task { await loadCounties() }
    }

    private func submit() async {
        errorMessage = nil
        infoMessage = nil
        isBusy = true
        defer { isBusy = false }

        let error: String?
        switch mode {
        case .signIn:
            error = await auth.signIn(email: email, password: password)
        case .signUp:
            guard let supportedCountyId else {
                errorMessage = "Please select the county you support."
                return
            }
            error = await auth.signUp(
                email: email,
                password: password,
                displayName: displayName,
                supportedCountyId: supportedCountyId
            )
        }

        if let error {
            errorMessage = error
        } else if mode == .signUp {
            infoMessage = "Account created! Check your inbox to confirm your email, then sign in."
            mode = .signIn
        }
    }

    private func loadCounties() async {
        do {
            counties = try await Supa.client
                .from("counties")
                .select()
                .order("name")
                .execute()
                .value
        } catch {
            errorMessage = "Counties could not be loaded. Please try again."
        }
    }
}
