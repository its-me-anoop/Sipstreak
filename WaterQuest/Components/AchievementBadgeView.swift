import SwiftUI

struct AchievementBadgeView: View {
    var achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Theme.sun : Color.white.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: achievement.isUnlocked ? "sparkles" : "lock.fill")
                    .foregroundColor(achievement.isUnlocked ? .black : .white.opacity(0.7))
            }
            Text(achievement.title)
                .font(Theme.bodyFont(size: 12))
                .foregroundColor(.white)
            Text(achievement.detail)
                .font(Theme.bodyFont(size: 10))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(maxWidth: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.card)
        )
    }
}
