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

            if quest.isCompleted {
                Text("Quest complete!")
                    .font(Theme.bodyFont(size: 12))
                    .foregroundColor(Theme.sun)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.card)
        )
    }
}
