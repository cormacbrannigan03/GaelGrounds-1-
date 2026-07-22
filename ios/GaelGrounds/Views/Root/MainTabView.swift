import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                MatchesView()
            }
            .tabItem { Label("Matches", systemImage: "sportscourt.fill") }

            NavigationStack {
                GroundsView()
            }
            .tabItem { Label("Grounds", systemImage: "mappin.and.ellipse") }

            NavigationStack {
                CountiesView()
            }
            .tabItem { Label("Counties", systemImage: "flag.fill") }

            NavigationStack {
                if auth.isSignedIn {
                    ProfileView()
                } else {
                    AuthView()
                }
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(.brandGreenLight)
    }
}
