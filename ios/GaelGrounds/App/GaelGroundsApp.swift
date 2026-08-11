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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(premium)
                .environmentObject(push)
                .environmentObject(supportedCounty)
                .task { await auth.startObserving() }
                .task { await premium.start() }
                .task(id: auth.userId) { premium.userId = auth.userId }
                .task(id: auth.userId) { supportedCounty.userId = auth.userId }
                .task(id: auth.userId) {
                    push.userId = auth.userId
                    if auth.userId != nil {
                        await push.requestAuthorizationAndRegister()
                    }
                }
        }
    }
}
