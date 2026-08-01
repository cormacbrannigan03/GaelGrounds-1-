import SwiftUI

@main
struct GaelGroundsApp: App {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var premium = PremiumStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(premium)
                .task { await premium.start() }
                .task(id: auth.userId) { premium.userId = auth.userId }
        }
    }
}
