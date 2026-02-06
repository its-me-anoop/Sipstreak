import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var store: HydrationStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var completedAchievements: Int {
        store.gameState.achievements.filter { $0.unlockedAt != nil }.count
    }

    private var completedQuests: Int {
        store.gameState.quests.filter { $0.isCompleted }.count
    }

    var body: some View {
        List {
            Section {
                summarySection
            }

            Section("Daily Missions") {
                if store.gameState.quests.isEmpty {
                    Text("No active quests right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.gameState.quests) { quest in
                        QuestStatusRow(quest: quest)
                    }
                }
            }

            Section("Milestones") {
                if store.gameState.achievements.isEmpty {
                    Text("Milestones will appear as you keep logging hydration.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.gameState.achievements) { achievement in
                            AchievementCell(achievement: achievement)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    store.refreshQuests()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progress at a glance")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                SummaryTile(title: "Streak", value: "\(store.gameState.streakDays) days", icon: "flame.fill", color: Theme.coral)
                SummaryTile(title: "Level", value: "\(store.gameState.level)", icon: "star.fill", color: Theme.sun)
                SummaryTile(title: "Coins", value: "\(store.gameState.coins)", icon: "bitcoinsign.circle.fill", color: Theme.lagoon)
            }

            HStack {
                Text("\(completedQuests)/\(max(1, store.gameState.quests.count)) quests complete")
                Spacer()
                Text("\(completedAchievements)/\(max(1, store.gameState.achievements.count)) milestones")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }
}

private struct QuestStatusRow: View {
    let quest: Quest

    private var progress: Double {
        min(1, quest.progressML / max(1, quest.targetML))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(quest.title)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(quest.isCompleted)
                    Text(quest.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("+\(quest.rewardXP)", systemImage: "star.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.sun)
            }

            ProgressView(value: progress)
                .tint(quest.isCompleted ? Theme.mint : Theme.lagoon)
        }
        .padding(.vertical, 2)
    }
}

private struct AchievementCell: View {
    let achievement: Achievement

    private var isUnlocked: Bool {
        achievement.unlockedAt != nil
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isUnlocked ? "trophy.fill" : "lock.fill")
                .font(.title3)
                .foregroundStyle(isUnlocked ? Theme.sun : .secondary)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Theme.cardElevated)
                )

            Text(achievement.title)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(isUnlocked ? "Unlocked" : achievement.detail)
                .font(.caption)
                .foregroundStyle(isUnlocked ? Theme.mint : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
    }
}

#Preview("Achievements") {
    PreviewEnvironment {
        AchievementsView()
    }
}
