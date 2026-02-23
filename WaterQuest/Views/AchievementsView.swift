import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        let count = sizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: count)
    }

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

    private var isRegular: Bool { sizeClass == .regular }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: isRegular ? 18 : 14) {
            Text("Progress at a glance")
                .font(isRegular ? .title2.weight(.semibold) : .title3.weight(.semibold))

            HStack(spacing: isRegular ? 16 : 12) {
                SummaryTile(title: "Streak", value: "\(store.gameState.streakDays) days", icon: "flame.fill", color: Theme.coral, isRegular: isRegular)
                SummaryTile(title: "Level", value: "\(store.gameState.level)", icon: "star.fill", color: Theme.sun, isRegular: isRegular)
                SummaryTile(title: "Coins", value: "\(store.gameState.coins)", icon: "bitcoinsign.circle.fill", color: Theme.lagoon, isRegular: isRegular)
            }

            HStack {
                Text("\(completedQuests)/\(max(1, store.gameState.quests.count)) quests complete")
                Spacer()
                Text("\(completedAchievements)/\(max(1, store.gameState.achievements.count)) milestones")
            }
            .font(isRegular ? .subheadline : .footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, isRegular ? 12 : 8)
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isRegular: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: isRegular ? 8 : 6) {
            Image(systemName: icon)
                .font(isRegular ? .title3 : .body)
                .foregroundStyle(color)
            Text(value)
                .font(isRegular ? .title3.weight(.semibold) : .headline)
            Text(title)
                .font(isRegular ? .subheadline : .caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isRegular ? 14 : 10)
        .background(
            RoundedRectangle(cornerRadius: isRegular ? 14 : 12, style: .continuous)
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
