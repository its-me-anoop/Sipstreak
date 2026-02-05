import SwiftUI

struct MainTabView: View {
    private enum Tab: Int {
        case dashboard
        case add
        case insights
        case achievements
        case settings
    }

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedTab: Tab = .dashboard
    @State private var showPaywall = false

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

            // Insights – gated
            ZStack {
                InsightsView()
                if !subscriptionManager.isPro {
                    LockedTabOverlay(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Insights",
                        onUnlock: { showPaywall = true }
                    )
                }
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Insights")
            }
            .tag(Tab.insights)

            // Quests – gated
            ZStack {
                AchievementsView()
                if !subscriptionManager.isPro {
                    LockedTabOverlay(
                        icon: "trophy.fill",
                        title: "Quests",
                        onUnlock: { showPaywall = true }
                    )
                }
            }
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
        .sheet(isPresented: $showPaywall) {
            PaywallView(isDismissible: true)
        }
    }
}

// MARK: - Locked Tab Overlay
/// Full-screen overlay rendered on top of a gated tab. Tapping "Unlock" opens the paywall.
private struct LockedTabOverlay: View {
    let icon: String
    let title: String
    let onUnlock: () -> Void

    @State private var glowPulse: CGFloat = 0

    var body: some View {
        ZStack {
            // Blurred backdrop so underlying content is hinted at but unreadable
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Lock icon with glow
                ZStack {
                    Circle()
                        .fill(Theme.lagoon.opacity(0.15 + glowPulse * 0.1))
                        .frame(width: 88, height: 88)
                        .blur(radius: glowPulse * 6)

                    Circle()
                        .fill(Theme.lagoon.opacity(0.22))
                        .frame(width: 72, height: 72)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    Text("\(title) is a Pro feature")
                        .font(Theme.titleFont(size: 20))
                        .foregroundColor(Theme.textPrimary)

                    Text("Subscribe to unlock insights, quests, and more")
                        .font(Theme.bodyFont(size: 14))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // Unlock button
                Button(action: {
                    Haptics.impact(.medium)
                    onUnlock()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Unlock Pro")
                            .font(Theme.titleFont(size: 16))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 36)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.lagoon, Theme.mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Theme.lagoon.opacity(0.45), radius: 14, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = 1
            }
        }
    }
}

#Preview("Main Tabs") {
    PreviewEnvironment {
        MainTabView()
    }
}
