import SwiftUI

struct RootView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "pawprint.fill") }
                .tag(0)
            NavigationStack { LeaderboardView() }
                .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }
                .tag(1)
            NavigationStack { ProfileView() }
                .tabItem { Label("You", systemImage: "person.fill") }
                .tag(2)
        }
    }
}
