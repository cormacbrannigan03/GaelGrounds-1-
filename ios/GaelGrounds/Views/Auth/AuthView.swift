import SwiftUI
import Supabase

struct AuthView: View {
    @EnvironmentObject private var auth: AuthViewModel

    private enum Mode { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var referralCode = ""
    @State private var counties: [County] = []
    @State private var supportedCountyId: UUID?
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isBusy = false
    @State private var confirmedAge16 = false

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

                    TextField("Referral code (optional)", text: $referralCode)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    // GDPR Article 6/8: Ireland sets the digital age of
                    // consent at 16, the maximum allowed under the
                    // regulation. Self-attestation, not ID verification --
                    // proportionate for an app like this, and the standard
                    // approach.
                    Toggle(isOn: $confirmedAge16) {
                        Text("I confirm I am 16 years of age or older.")
                            .font(.footnote)
                    }
                    .tint(.brandGreen)
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
                    (mode == .signUp && supportedCountyId == nil) ||
                    (mode == .signUp && !confirmedAge16)
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
            guard confirmedAge16 else {
                errorMessage = "You must confirm you are 16 or older to create an account."
                return
            }
            error = await auth.signUp(
                email: email,
                password: password,
                displayName: displayName,
                supportedCountyId: supportedCountyId,
                referralCode: referralCode
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
