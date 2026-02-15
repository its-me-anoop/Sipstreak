import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private static let defaultMascotID = "ripple"
    private let mascotOptions: [MascotOption] = [
        MascotOption(id: "ripple", name: "Ripple", tagline: "Classic aqua companion", systemImage: "drop.fill", colors: [Theme.lagoon, Theme.mint]),
        MascotOption(id: "blaze", name: "Blaze", tagline: "Fiery streak booster", systemImage: "flame.fill", colors: [Theme.coral, Theme.sun]),
        MascotOption(id: "leafy", name: "Leafy", tagline: "Fresh and balanced", systemImage: "leaf.fill", colors: [Theme.mint, Theme.lagoon]),
        MascotOption(id: "bolt", name: "Bolt", tagline: "Lightning quick energy", systemImage: "bolt.fill", colors: [Theme.lavender, Theme.lagoon]),
        MascotOption(id: "frost", name: "Frost", tagline: "Cool and collected", systemImage: "snowflake", colors: [Theme.lagoon.opacity(0.7), Theme.lavender])
    ]

    @AppStorage("WaterQuest.selectedMascot") private var selectedMascotID: String = AchievementsView.defaultMascotID
    @State private var showPaywall = false

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

            Section {
                mascotSection
            } header: {
                HStack(spacing: 8) {
                    Text("Mascot Collection")
                    if !subscriptionManager.isPro {
                        Text("PRO")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.sun))
                    }
                }
            } footer: {
                Text(subscriptionManager.isPro
                     ? "Pick a mascot to accompany your hydration quests."
                     : "Unlock the full mascot collection with Thirsty.ai Pro.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        .sheet(isPresented: $showPaywall) {
            PaywallView(isDismissible: true)
        }
        .onAppear {
            enforceMascotSelectionRules()
        }
        .onChange(of: subscriptionManager.isPro) { _, _ in
            enforceMascotSelectionRules()
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

    private var mascotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(mascotOptions) { option in
                    Button {
                        handleMascotSelection(option)
                    } label: {
                        MascotCard(
                            option: option,
                            isSelected: selectedMascotID == option.id,
                            isLocked: isMascotLocked(option)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !subscriptionManager.isPro {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Unlock mascot collection")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(Theme.sun)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func handleMascotSelection(_ option: MascotOption) {
        if subscriptionManager.isPro {
            Haptics.selection()
            selectedMascotID = option.id
        } else {
            showPaywall = true
        }
    }

    private func isMascotLocked(_ option: MascotOption) -> Bool {
        !subscriptionManager.isPro
    }

    private func enforceMascotSelectionRules() {
        if !subscriptionManager.isPro, selectedMascotID != Self.defaultMascotID {
            selectedMascotID = Self.defaultMascotID
        }
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

private struct MascotOption: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let systemImage: String
    let colors: [Color]
}

private struct MascotCard: View {
    let option: MascotOption
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: option.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 72)

                    Image(systemName: option.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(option.name)
                    .font(.subheadline.weight(.semibold))

                Text(option.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isSelected && !isLocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.mint)
                    .padding(6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Theme.mint : Theme.glassBorder, lineWidth: isSelected ? 1.5 : 1)
        )
        .overlay(lockedOverlay)
    }

    @ViewBuilder
    private var lockedOverlay: some View {
        if isLocked {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Image(systemName: "lock.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.sun)
                )
        }
    }
}

#Preview("Achievements") {
    PreviewEnvironment {
        AchievementsView()
    }
}
