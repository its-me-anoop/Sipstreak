import SwiftUI

struct MainTabView: View {
    private enum Tab: Int {
        case dashboard
        case add
        case insights
        case achievements
        case settings
    }

    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "drop.fill")
                    Text("Today")
                }
                .tag(Tab.dashboard)
            AddIntakeView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
                .tag(Tab.add)
            InsightsView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Insights")
                }
                .tag(Tab.insights)
            AchievementsView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Quests")
                }
                .tag(Tab.achievements)
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(Tab.settings)
        }
        .tint(Theme.mint)
        .onChange(of: selectedTab) {
            Haptics.selection()
        }
    }
}

#Preview("Main Tabs") {
    PreviewEnvironment {
        MainTabView()
    }
}
