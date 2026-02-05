import SwiftUI

struct AchievementBadgeView: View {
    var achievement: Achievement

    @State private var pulse = false
    @State private var twinkle = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Theme.sun : Theme.glassLight)
                    .frame(width: 56, height: 56)
                Image(systemName: achievement.isUnlocked ? "sparkles" : "lock.fill")
                    .foregroundColor(achievement.isUnlocked ? .black : Theme.textSecondary)
                    .rotationEffect(.degrees(twinkle && achievement.isUnlocked ? 12 : 0))
                    .scaleEffect(twinkle && achievement.isUnlocked ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: twinkle)
            }
            Text(achievement.title)
                .font(Theme.bodyFont(size: 12))
                .foregroundColor(Theme.textPrimary)
            Text(achievement.detail)
                .font(Theme.bodyFont(size: 10))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(maxWidth: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.card)
        )
        .scaleEffect(pulse ? 1.04 : 1.0)
        .shadow(color: achievement.isUnlocked ? Theme.sun.opacity(pulse ? 0.5 : 0.2) : .clear, radius: pulse ? 12 : 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pulse)
        .onAppear {
            if achievement.isUnlocked {
                twinkle = true
            }
        }
        .onChange(of: achievement.isUnlocked) { _, unlocked in
            guard unlocked else { return }
            twinkle = true
            pulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                pulse = false
            }
        }
    }
}
