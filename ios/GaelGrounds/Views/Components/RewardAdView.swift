import SwiftUI
import GoogleMobileAds

/// Presents the "watch a video, unlock 1 more match today" flow using a
/// real Google AdMob rewarded ad.
struct RewardAdView: View {
    /// Called once the reward is earned (AdMob's reward-earned callback fired).
    var onCompleted: () -> Void
    /// Called if the user backs out, the ad fails to load, or is dismissed
    /// before the reward is earned -- a rewarded ad grants nothing in that case.
    var onCancel: () -> Void

    /// Google's official sample rewarded ad unit -- always serves a test ad,
    /// regardless of AdMob account config. Used for DEBUG builds (Xcode
    /// runs on simulator/unregistered devices) so testing never risks the
    /// AdMob account being flagged for invalid traffic. Release builds
    /// (TestFlight/App Store) use the real ad unit.
    #if DEBUG
    private static let adUnitID = "ca-app-pub-3940256099942544/1712485313"
    #else
    private static let adUnitID = "ca-app-pub-9676786622570370/5265583700"
    #endif

    @State private var coordinator = Coordinator()
    @State private var state: LoadState = .loading
    @State private var errorMessage: String?

    private enum LoadState {
        case loading
        case ready
        case presenting
        case failed
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.brandGold)

            switch state {
            case .loading:
                Text("Loading ad…")
                    .font(.title3.bold())
                ProgressView()
            case .ready, .presenting:
                Text("Watching ad…")
                    .font(.title3.bold())
                Text("Unlocks 1 extra match once this finishes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView()
            case .failed:
                Text("Ad unavailable")
                    .font(.title3.bold())
                Text(errorMessage ?? "Couldn't load an ad right now. Please try again later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .padding()
        .task {
            await loadAndPresent()
        }
    }

    @MainActor
    private func loadAndPresent() async {
        coordinator.onReward = {
            state = .presenting
        }
        coordinator.onDismissed = { earnedReward in
            if earnedReward {
                onCompleted()
            } else {
                onCancel()
            }
        }

        do {
            let request = Request()
            let ad = try await RewardedAd.load(with: Self.adUnitID, request: request)
            state = .ready
            guard let presentingVC = Self.topMostViewController() else {
                state = .failed
                errorMessage = "Couldn't present the ad right now."
                return
            }

            ad.fullScreenContentDelegate = coordinator
            ad.present(from: presentingVC) {
                coordinator.earnedReward = true
                coordinator.onReward?()
            }
        } catch {
            state = .failed
            errorMessage = "Couldn't load an ad right now. Please try again later."
        }
    }

    /// AdMob must present from the topmost already-presented view controller.
    /// This view is itself shown inside a `.fullScreenCover`, so the window's
    /// `rootViewController` already has a presented VC on top of it -- handing
    /// that straight to AdMob silently fails to present. Walk the
    /// `presentedViewController` chain to find the real top of the stack.
    @MainActor
    private static func topMostViewController() -> UIViewController? {
        guard var top = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController
        else { return nil }

        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

/// Bridges AdMob's delegate-based dismissal callback back into SwiftUI state.
private final class Coordinator: NSObject, FullScreenContentDelegate {
    var earnedReward = false
    var onReward: (() -> Void)?
    var onDismissed: ((_ earnedReward: Bool) -> Void)?

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onDismissed?(false)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onDismissed?(earnedReward)
    }
}
