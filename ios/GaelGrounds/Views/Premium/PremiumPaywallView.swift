import SwiftUI

/// Shown from every free-tier gate: the 10-match cap, a blocked pre-2019
/// match, a blocked friend request, and the leaderboard's "go premium to
/// appear here" prompt. `reason` lets each call site explain why the
/// sheet appeared without needing its own bespoke paywall copy.
struct PremiumPaywallView: View {
    var reason: String?

    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private var priceText: String {
        premium.monthlyProduct?.displayPrice ?? "€1.99"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let reason {
                        Text(reason)
                            .font(.subheadline.bold())
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .gaelCard(cornerRadius: 12)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("GaelGrounds Premium").font(.title2.bold())
                        Text("\(priceText) / month").foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        perk("infinity", "Unlimited match logging", "No cap on check-ins or matches you add yourself.")
                        perk("clock.arrow.circlepath", "Log any year", "Add matches from before 2019, not just recent ones.")
                        perk("person.2.fill", "Add friends", "Send friend requests and follow their record.")
                        perk("trophy.fill", "Appear on leaderboards", "Free accounts can browse the leaderboard but aren't ranked on it.")
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await purchase() }
                    } label: {
                        if isPurchasing {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Subscribe — \(priceText)/month").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandGreen)
                    .disabled(isPurchasing || isRestoring)

                    Button {
                        Task { await restore() }
                    } label: {
                        if isRestoring {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Restore Purchases").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPurchasing || isRestoring)

                    Text("Cancel any time in Settings › Apple ID › Subscriptions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // App Store Review Guideline 3.1.2 requires the purchase
                    // screen itself to disclose auto-renewal terms and link
                    // to both policies, not just have them somewhere else
                    // in the app.
                    Text("GaelGrounds Premium automatically renews monthly at \(priceText) until cancelled. Payment is charged to your Apple ID account at confirmation of purchase. Your subscription renews automatically unless auto-renew is turned off at least 24 hours before the end of the current period. Manage or cancel any time in Settings › Apple ID › Subscriptions.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Link("Privacy Policy", destination: URL(string: "https://www.gaelgrounds.ie/privacy.html")!)
                        Link("Terms of Service", destination: URL(string: "https://www.gaelgrounds.ie/terms.html")!)
                    }
                    .font(.caption2)
                }
                .padding()
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if premium.monthlyProduct == nil {
                    await premium.loadProduct()
                }
            }
            .onChange(of: premium.isPremium) { isPremium in
                if isPremium { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func perk(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.brandGold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func purchase() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await premium.purchase()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }
        do {
            try await premium.restorePurchases()
            if !premium.isPremium {
                errorMessage = "No active subscription found for this Apple ID."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
