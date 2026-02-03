import SwiftUI

struct QuestCard: View {
    var quest: Quest
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title)
                        .font(Theme.titleFont(size: 16))
                    Text(quest.detail)
                        .font(Theme.bodyFont(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text("+\(quest.rewardXP) XP")
                    .font(Theme.bodyFont(size: 12))
                    .padding(6)
                    .background(Theme.sun.opacity(0.2))
                    .clipShape(Capsule())
            }

            ProgressView(value: progress)
                .tint(Theme.mint)
                .background(Color.white.opacity(0.1))
                .animation(.easeInOut(duration: 0.5), value: progress)

            if quest.isCompleted {
                Text("Quest complete!")
                    .font(Theme.bodyFont(size: 12))
                    .foregroundColor(Theme.sun)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.sun.opacity(quest.isCompleted ? 0.35 : 0.08), lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: quest.isCompleted)
    }
}
