import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var proximityCheckIn: ProximityCheckInService

    var body: some View {
        MainTabView()
            .alert(
                "Check in at \(proximityCheckIn.nearbyPrompt?.groundName ?? "this ground")?",
                isPresented: Binding(
                    get: { proximityCheckIn.nearbyPrompt != nil },
                    set: { isPresented in
                        if !isPresented { proximityCheckIn.dismissPrompt() }
                    }
                )
            ) {
                Button("Check In") {
                    Task { await proximityCheckIn.confirmCheckIn() }
                }
                Button("Not Now", role: .cancel) {
                    proximityCheckIn.dismissPrompt()
                }
            } message: {
                Text("There's a match on today and you're nearby — want to check in?")
            }
    }
}
