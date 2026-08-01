import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var selectedTab = 0

    private struct TabItem {
        let tag: Int
        let label: String
        let icon: String
    }

    private let tabs: [TabItem] = [
        .init(tag: 0, label: "Home",        icon: "house.fill"),
        .init(tag: 1, label: "Matches",     icon: "sportscourt.fill"),
        .init(tag: 2, label: "Grounds",     icon: "mappin.and.ellipse"),
        .init(tag: 3, label: "Counties",    icon: "flag.fill"),
        .init(tag: 4, label: "Leaderboard", icon: "trophy.fill"),
        .init(tag: 5, label: "Profile",     icon: "person.crop.circle"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ZStack {
                NavigationStack { DashboardView() }
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)

                NavigationStack { MatchesView() }
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)

                NavigationStack { GroundsView() }
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)

                NavigationStack { CountiesView() }
                    .opacity(selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 3)

                NavigationStack { LeaderboardView() }
                    .opacity(selectedTab == 4 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 4)

                NavigationStack {
                    if auth.isSignedIn { ProfileView() } else { AuthView() }
                }
                .opacity(selectedTab == 5 ? 1 : 0)
                .allowsHitTesting(selectedTab == 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(tabs, id: \.tag) { tab in
                    Button {
                        selectedTab = tab.tag
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 19, weight: selectedTab == tab.tag ? .semibold : .regular))
                            Text(tab.label)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab.tag ? Color.brandGreen : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selectedTab == tab.tag {
                                Capsule()
                                    .fill(Color.brandGreenLight.opacity(0.12))
                                    .overlay {
                                        Capsule().stroke(Color.brandGold.opacity(0.26), lineWidth: 1)
                                    }
                                    .padding(.horizontal, 3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 5)
            .padding(.top, 5)
            .padding(.bottom, 2)
            .background(Color.brandSurfaceRaised.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [.brandGreen.opacity(0.08), .brandGold.opacity(0.48), .brandGreen.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
            }
            .shadow(color: Color.brandGreen.opacity(0.10), radius: 10, y: -3)
        }
        .ignoresSafeArea(.keyboard)
        .tint(.brandGreenLight)
    }
}
