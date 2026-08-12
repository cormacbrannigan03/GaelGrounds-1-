import SwiftUI

@main
struct GaelGroundsApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @StateObject private var auth = AuthViewModel()
    @StateObject private var premium = PremiumStore()
    @StateObject private var push = PushNotificationService.shared
    @StateObject private var supportedCounty = SupportedCountyStore()
    @StateObject private var proximityCheckIn = ProximityCheckInService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(premium)
                .environmentObject(push)
                .environmentObject(supportedCounty)
                .environmentObject(proximityCheckIn)
                .task { await auth.startObserving() }
                .task { await premium.start() }
                .task(id: auth.userId) { premium.userId = auth.userId }
                .task(id: auth.userId) { supportedCounty.userId = auth.userId }
                .task(id: auth.userId) { proximityCheckIn.userId = auth.userId }
                .task(id: auth.userId) {
                    push.userId = auth.userId
                    if auth.userId != nil {
                        await push.requestAuthorizationAndRegister()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active, let userId = auth.userId else { return }
                    Task { await proximityCheckIn.checkForNearbyMatchToday(userId: userId, isPremium: premium.isPremium) }
                }
        }
    }
}
