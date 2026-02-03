import SwiftUI

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @EnvironmentObject private var store: HydrationStore

    var body: some View {
        ZStack {
            if hasOnboarded {
                MainTabView()
            } else {
                OnboardingView {
                    hasOnboarded = true
                }
            }

            if let achievement = store.activeAchievement {
                AchievementCelebrationView(achievement: achievement) {
                    store.dismissActiveAchievement()
                }
                .id(achievement.id)
                .transition(AnyTransition.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: store.activeAchievement)
    }
}
