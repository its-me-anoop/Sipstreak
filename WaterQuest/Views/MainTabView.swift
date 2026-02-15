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
    @State private var lastNonAddTab: Tab = .dashboard
    @State private var showAddIntakeSheet = false
    @State private var isLogPulseActive = false

    init() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundColor = .clear
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    var body: some View {
        ZStack {
            AppWaterBackground().ignoresSafeArea()

            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView()
                }
                .background(Color.clear)
                .toolbarBackground(.hidden, for: .navigationBar)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.dashboard)

                NavigationStack {
                    InsightsView()
                }
                .background(Color.clear)
                .toolbarBackground(.hidden, for: .navigationBar)
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.insights)

                Color.clear
                    .tabItem {
                        Label("Log", systemImage: "plus.circle.fill")
                    }
                    .tag(Tab.add)

                NavigationStack {
                    AchievementsView()
                }
                .background(Color.clear)
                .toolbarBackground(.hidden, for: .navigationBar)
                .tabItem {
                    Label("Goals", systemImage: "trophy")
                }
                .tag(Tab.achievements)

                NavigationStack {
                    SettingsView()
                }
                .background(Color.clear)
                .toolbarBackground(.hidden, for: .navigationBar)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
            }
            .background(Color.clear)

            addLogFloatingButton
                .ignoresSafeArea(edges: .bottom)
        }
        .tint(Theme.lagoon)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isLogPulseActive = true
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            Haptics.selection()
            if newValue == .add {
                showAddIntakeSheet = true
                selectedTab = lastNonAddTab
            } else {
                lastNonAddTab = newValue
            }
        }
        .sheet(isPresented: $showAddIntakeSheet) {
            NavigationStack {
                AddIntakeView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var addLogFloatingButton: some View {
        VStack {
            Spacer()

            Button {
                Haptics.impact(.medium)
                showAddIntakeSheet = true
            } label: {
                ZStack {
                    Circle()
                        .stroke(Theme.lagoon.opacity(0.35), lineWidth: 10)
                        .frame(width: 76, height: 76)
                        .scaleEffect(isLogPulseActive ? 1.15 : 0.9)
                        .opacity(isLogPulseActive ? 0.0 : 1.0)

                    Circle()
                        .fill(Theme.lagoon)
                        .frame(width: 58, height: 58)
                        .shadow(color: Theme.lagoon.opacity(0.35), radius: 12, x: 0, y: 6)

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(OpaqueButtonStyle())
            .padding(.bottom, 13)
            .accessibilityLabel("Log water")
            .accessibilityHint("Opens the add intake sheet")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private struct OpaqueButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(1)
        }
    }

}

#if DEBUG
#Preview("Main Tabs") {
    PreviewEnvironment {
        MainTabView()
    }
}
#endif
