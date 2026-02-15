import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var store: HydrationStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private static let defaultMascotID = MascotStyle.ripple.rawValue
    private let mascotOptions: [MascotStyle] = MascotStyle.allCases

    @AppStorage("WaterQuest.selectedMascot") private var selectedMascotID: String = AchievementsView.defaultMascotID


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
                }
            } footer: {
                Text("Pick a mascot to accompany your hydration quests.")
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
        .onAppear {
            enforceMascotSelectionRules()
        }
    }

    private var proContent: some View {
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
                }
            } footer: {
                Text("Pick a mascot to accompany your hydration quests.")
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
    }


    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progress at a glance")
                .font(.title3.weight(.semibold))

            SummaryTile(title: "Streak", value: "\(store.gameState.streakDays) days", icon: "flame.fill", color: Theme.coral)

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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
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
                .padding(.horizontal, 12)
            }
            .scrollClipDisabled()

        }
        .padding(.vertical, 4)
    }


    private func handleMascotSelection(_ option: MascotStyle) {
        Haptics.selection()
        selectedMascotID = option.id
    }

    private func isMascotLocked(_ option: MascotStyle) -> Bool {
        false
    }

    private func enforceMascotSelectionRules() {
        guard mascotOptions.contains(where: { $0.id == selectedMascotID }) else {
            selectedMascotID = Self.defaultMascotID
            return
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

                if quest.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.mint)
                }
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

private struct MascotCard: View {
    let option: MascotStyle
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
                        .frame(height: 96)

                    MascotPreview(option: option)
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
        .frame(width: 170, alignment: .leading)
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

private struct MascotPreview: View {
    let option: MascotStyle

    @State private var bobOffset: CGFloat = 0
    @State private var blink: Bool = false
    @State private var glowScale: CGFloat = 1

    private let size: CGFloat = 58

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: size * 1.6, height: size * 1.6)
                .scaleEffect(glowScale)
                .blur(radius: 10)

            gradient
                .mask(maskShape)
                .frame(width: size * 1.1, height: size * 1.25)
                .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 4)

            mascotFace
                .offset(y: size * 0.1)
        }
        .offset(y: bobOffset)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                bobOffset = -4
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glowScale = 1.12
            }
            startBlinking()
        }
    }

    private var gradient: some View {
        LinearGradient(
            colors: option.colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .hueRotation(.degrees(option.hueRotation))
    }

    private var maskShape: some View {
        switch option {
        case .ripple:
            return AnyView(
                Image(systemName: "drop.fill")
                    .resizable()
                    .scaledToFit()
            )
        case .blaze:
            return AnyView(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .rotation(.degrees(8))
            )
        case .leafy:
            return AnyView(
                Capsule(style: .continuous)
                    .rotation(.degrees(-18))
            )
        case .bolt:
            return AnyView(DiamondShape())
        case .frost:
            return AnyView(HexagonShape())
        }
    }

    private var mascotFace: some View {
        VStack(spacing: size * 0.08) {
            HStack(spacing: size * 0.14) {
                eye
                eye
            }

            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.28, height: size * 0.07)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.6))
                        .frame(width: size * 0.16, height: size * 0.05)
                        .offset(y: size * 0.02)
                )
        }
    }

    private var eye: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.95))
            .frame(width: size * 0.12, height: blink ? size * 0.03 : size * 0.12)
            .overlay(
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: size * 0.05, height: size * 0.05)
                    .opacity(blink ? 0 : 1)
                    .offset(y: size * 0.01)
            )
            .animation(.easeInOut(duration: 0.12), value: blink)
    }

    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 3.6, repeats: true) { _ in
            blink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                blink = false
            }
        }
    }
}

#if DEBUG
#Preview("Achievements") {
    PreviewEnvironment {
        AchievementsView()
    }
}
#endif
