import SwiftUI
import Supabase

private struct ReferralProfile: Decodable {
    let referralCode: String
    let referralMonthsGranted: Int
}

private struct ReferredProfile: Decodable {
    let id: UUID
    let displayName: String?
}

private struct ReferredRow: Identifiable {
    let id: UUID
    let displayName: String?
    let qualified: Bool
}

private struct AttendanceUserRef: Decodable {
    let userId: UUID
}

/// The Profile > Referral Code screen -- shows the signed-in user's
/// shareable code and their progress toward the next free Premium month.
/// Mirrors ReferralTab.tsx: 3 referred accounts that have each logged at
/// least one match earns 1 free month, repeating for every further group
/// of 3.
struct ReferralView: View {
    let userId: UUID

    @State private var code: String?
    @State private var monthsGranted = 0
    @State private var referred: [ReferredRow] = []
    @State private var isLoading = true

    private let goal = 3

    private var shareLink: URL {
        URL(string: "https://app.gaelgrounds.ie/auth?ref=\(code ?? "")") ?? URL(string: "https://app.gaelgrounds.ie")!
    }

    private var qualifiedCount: Int { referred.filter(\.qualified).count }

    private var remaining: Int {
        let towardNext = qualifiedCount % goal
        return towardNext == 0 ? 0 : goal - towardNext
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let code {
                    VStack(spacing: 10) {
                        Text("Your referral code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(code)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .tracking(4)
                            .foregroundStyle(.brandGreenLight)
                        ShareLink(item: shareLink) {
                            Label("Share invite link", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brandGreen)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .gaelCard(cornerRadius: 14)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(qualifiedCount) friend\(qualifiedCount == 1 ? "" : "s") you referred \(qualifiedCount == 1 ? "has" : "have") checked in to a match.")
                            .font(.subheadline.bold())
                        Text(
                            "Every \(goal) friends who sign up with your link and log a match earns you a free month of Premium."
                            + (remaining > 0 ? " \(remaining) more to your next free month." : "")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        if monthsGranted > 0 {
                            Text("🎉 You've earned \(monthsGranted) free month\(monthsGranted == 1 ? "" : "s") of Premium so far.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .gaelCard(cornerRadius: 14)

                    if !referred.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Friends you've referred").font(.title3.bold())
                            VStack(spacing: 8) {
                                ForEach(referred) { r in
                                    HStack {
                                        Text(r.displayName ?? "A fan").font(.subheadline)
                                        Spacer()
                                        Text(r.qualified ? "✓ Checked in" : "Waiting on first check-in")
                                            .font(.caption)
                                            .foregroundStyle(r.qualified ? Color.brandGreenLight : .secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                } else {
                    Text("Couldn't load your referral code — try again shortly.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Referral Code")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .gaelGroundsBackground()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let profile: ReferralProfile = try await Supa.client
                .from("user_profiles")
                .select("referral_code, referral_months_granted")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            code = profile.referralCode
            monthsGranted = profile.referralMonthsGranted

            let referredProfiles: [ReferredProfile] = try await Supa.client
                .from("user_profiles")
                .select("id, display_name")
                .eq("referred_by_user_id", value: userId)
                .execute()
                .value

            let referredIds = referredProfiles.map(\.id)
            var qualifiedIds = Set<UUID>()
            if !referredIds.isEmpty {
                let attendance: [AttendanceUserRef] = try await Supa.client
                    .from("user_match_attendance")
                    .select("user_id")
                    .in("user_id", values: referredIds)
                    .execute()
                    .value
                qualifiedIds = Set(attendance.map(\.userId))
            }

            referred = referredProfiles.map {
                ReferredRow(id: $0.id, displayName: $0.displayName, qualified: qualifiedIds.contains($0.id))
            }
        } catch {
            print("ReferralView load failed: \(error)")
        }
    }
}
