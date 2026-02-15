import SwiftUI

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage("hasOnboardedLocally") private var hasOnboardedLocally: Bool = false
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var showSplash = true
    @State private var showTrialExpiredPaywall = false
    @State private var pendingPaywallCheck = false

    var body: some View {
        ZStack {
            if hasOnboardedLocally {
                MainTabView()
            } else {
                OnboardingView {
                    hasOnboarded = true
                    hasOnboardedLocally = true
                }
            }

            if subscriptionManager.isPro, let achievement = store.activeAchievement {
                AchievementCelebrationView(achievement: achievement) {
                    store.dismissActiveAchievement()
                }
                .id(achievement.id)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(8)
            }

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: store.activeAchievement)
        .task {
            await bootstrapAppFlow()
        }
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            if isPro {
                showTrialExpiredPaywall = false
            } else if hasOnboardedLocally {
                showTrialExpiredPaywall = true
            }
        }
        .onChange(of: subscriptionManager.isInitialized) { _, initialized in
            guard initialized, pendingPaywallCheck, hasOnboardedLocally else { return }
            pendingPaywallCheck = false
            showTrialExpiredPaywall = !subscriptionManager.isPro
        }
        .sheet(isPresented: $showTrialExpiredPaywall) {
            PaywallView(isDismissible: false)
        }
    }

    private func bootstrapAppFlow() async {
        guard showSplash else { return }

        try? await Task.sleep(for: .seconds(1.0))

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                showSplash = false
            }
        }

        guard hasOnboardedLocally else { return }

        if subscriptionManager.isInitialized {
            if !subscriptionManager.isPro {
                showTrialExpiredPaywall = true
            }
        } else {
            pendingPaywallCheck = true
        }
    }
}
