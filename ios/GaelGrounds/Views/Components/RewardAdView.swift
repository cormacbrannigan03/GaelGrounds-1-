import SwiftUI

/// Presents the "watch a video, unlock 1 more match today" flow.
///
/// PLACEHOLDER IMPLEMENTATION: there's no AdMob (or other ad network) SDK
/// wired into this project yet -- adding one blind, without a working
/// Xcode toolchain to compile and test the dependency, risks breaking the
/// build in a way nobody could catch until a real device/simulator run.
/// So for now this simulates watching a rewarded video with a fixed
/// countdown, then calls `onCompleted` exactly like a real ad SDK's
/// reward callback would.
///
/// TO SWAP IN A REAL AD SDK LATER: once Google Mobile Ads (or similar) is
/// added as a Swift Package dependency and an ad unit ID exists, replace
/// this view's body with that SDK's rewarded-ad presentation call, and
/// invoke `onCompleted` from its reward-earned callback instead of the
/// timer below. Every call site below (RewardAdView(onCompleted:onCancel:))
/// stays the same -- this file is the only thing that needs to change.
struct RewardAdView: View {
    /// Called once the (simulated) reward is earned.
    var onCompleted: () -> Void
    /// Called if the user backs out before the reward is earned -- a real
    /// rewarded ad grants nothing if dismissed early, so this placeholder
    /// doesn't either.
    var onCancel: () -> Void

    private let totalSeconds = 15
    @State private var secondsRemaining: Int
    @State private var timer: Timer?

    init(onCompleted: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onCompleted = onCompleted
        self.onCancel = onCancel
        self._secondsRemaining = State(initialValue: 15)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.brandGold)

            Text("Watching ad…")
                .font(.title3.bold())

            Text("Unlocks 1 extra match once this finishes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(totalSeconds - secondsRemaining), total: Double(totalSeconds))
                .padding(.horizontal, 40)

            Text("\(secondsRemaining)s")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            Button("Cancel") {
                stopTimer()
                onCancel()
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .padding()
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                guard secondsRemaining > 0 else { return }
                secondsRemaining -= 1
                if secondsRemaining == 0 {
                    stopTimer()
                    onCompleted()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
