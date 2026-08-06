import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        MainTabView()
    }
}
