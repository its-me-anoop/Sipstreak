import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var store: HydrationStore

    @State private var appearAnimation = false
    @State private var selectedQuest: Quest? = nil
    @State private var showingQuestDetail = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack(alignment: .top) {
            // Animated background
            AchievementsBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header section
                    headerSection
                        .offset(y: appearAnimation ? 0 : -20)
                        .opacity(appearAnimation ? 1 : 0)

                    // Stats overview
                    statsOverview
                        .offset(y: appearAnimation ? 0 : 20)
                        .opacity(appearAnimation ? 1 : 0)

                    // Today's Quests section
                    questsSection
                        .offset(y: appearAnimation ? 0 : 30)
                        .opacity(appearAnimation ? 1 : 0)

                    // Achievements section
                    achievementsSection
                        .offset(y: appearAnimation ? 0 : 40)
                        .opacity(appearAnimation ? 1 : 0)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: store.gameState.achievements)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: store.gameState.quests)
        .onAppear {
            withAnimation(Theme.fluidSpring.delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Quests & Badges")
                    .font(Theme.titleFont(size: 28))
                    .foregroundColor(.white)

                Text("Complete challenges, earn rewards")
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Refresh button with animation
            RefreshButton {
                Haptics.impact(.medium)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    store.refreshQuests()
                }
            }
        }
    }

    // MARK: - Stats Overview
    private var statsOverview: some View {
        HStack(spacing: 12) {
            MiniStatCard(
                icon: "flame.fill",
                value: "\(store.gameState.streakDays)",
                label: "Day Streak",
                color: Theme.coral
            )

            MiniStatCard(
                icon: "star.fill",
                value: "\(store.gameState.level)",
                label: "Level",
                color: Theme.sun
            )

            MiniStatCard(
                icon: "trophy.fill",
                value: "\(completedAchievements)",
                label: "Badges",
                color: Theme.mint
            )
        }
    }

    private var completedAchievements: Int {
        store.gameState.achievements.filter { $0.unlockedAt != nil }.count
    }

    // MARK: - Quests Section
    private var questsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.lagoon)

                Text("Today's Quests")
                    .font(Theme.titleFont(size: 18))
                    .foregroundColor(.white)

                Spacer()

                Text("\(completedQuests)/\(store.gameState.quests.count)")
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }

            ForEach(Array(store.gameState.quests.enumerated()), id: \.element.id) { index, quest in
                let progress = min(1, quest.progressML / max(1, quest.targetML))
                QuestCard(quest: quest, progress: progress)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                    .animation(Theme.fluidSpring.delay(Double(index) * 0.05), value: store.gameState.quests)
            }
        }
    }

    private var completedQuests: Int {
        store.gameState.quests.filter { $0.progressML >= $0.targetML }.count
    }

    // MARK: - Achievements Section
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.sun)

                Text("Achievements")
                    .font(Theme.titleFont(size: 18))
                    .foregroundColor(.white)

                Spacer()

                Text("\(completedAchievements) unlocked")
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(store.gameState.achievements.enumerated()), id: \.element.id) { index, achievement in
                    EnhancedAchievementBadge(achievement: achievement)
                        .transition(.scale.combined(with: .opacity))
                        .animation(Theme.fluidSpring.delay(Double(index) * 0.03), value: store.gameState.achievements)
                }
            }
        }
    }
}

// MARK: - Refresh Button
private struct RefreshButton: View {
    let action: () -> Void

    @State private var isPressed = false
    @State private var rotation: Double = 0

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                rotation += 360
            }
            action()
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(Theme.lagoon.opacity(0.2))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )

                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: 44, height: 44)
            .shadow(color: Theme.lagoon.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.9 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(Theme.quickSpring) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(Theme.quickSpring) { isPressed = false }
                }
        )
    }
}

// MARK: - Mini Stat Card
private struct MiniStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    @State private var glowPulse: CGFloat = 0

    var body: some View {
        LiquidGlassCard(cornerRadius: 18, tintColor: color.opacity(0.5), isInteractive: false) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15 + glowPulse * 0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(value)
                    .font(Theme.titleFont(size: 20))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())

                Text(label)
                    .font(Theme.bodyFont(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = 1
            }
        }
    }
}

// MARK: - Enhanced Achievement Badge
private struct EnhancedAchievementBadge: View {
    let achievement: Achievement

    @State private var isPressed = false
    @State private var bounceScale: CGFloat = 1

    private var isUnlocked: Bool {
        achievement.unlockedAt != nil
    }

    var body: some View {
        LiquidGlassCard(
            cornerRadius: 20,
            tintColor: isUnlocked ? Theme.sun.opacity(0.5) : Color.gray.opacity(0.3),
            isInteractive: true
        ) {
            VStack(spacing: 12) {
                // Icon with effects
                ZStack {
                    // Background circle
                    Circle()
                        .fill(
                            isUnlocked
                                ? LinearGradient(
                                    colors: [Theme.sun.opacity(0.3), Theme.coral.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 52, height: 52)

                    // Icon
                    Image(systemName: isUnlocked ? "trophy.fill" : "trophy")
                        .font(.system(size: 26))
                        .foregroundColor(isUnlocked ? Theme.sun : .gray)
                        .opacity(isUnlocked ? 1 : 0.5)
                        .scaleEffect(bounceScale)
                }

                // Title
                Text(achievement.title)
                    .font(Theme.bodyFont(size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Status
                if isUnlocked {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Unlocked")
                            .font(Theme.bodyFont(size: 10))
                    }
                    .foregroundColor(Theme.mint)
                } else {
                    Text(achievement.detail)
                        .font(Theme.bodyFont(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
        }
        .scaleEffect(isPressed ? 0.95 : 1)
        .animation(Theme.quickSpring, value: isPressed)
        .onChange(of: isUnlocked) { _, newValue in
            if newValue {
                // Bounce animation on unlock
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    bounceScale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        bounceScale = 1
                    }
                }
                Haptics.achievement()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Achievements Background
private struct AchievementsBackground: View {
    @State private var starOpacities: [CGFloat] = Array(repeating: 0.3, count: 20)

    var body: some View {
        ZStack {
            Theme.background

            // Floating particles/stars effect
            GeometryReader { geometry in
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(Theme.sun.opacity(starOpacities[index]))
                        .frame(width: CGFloat.random(in: 2...6), height: CGFloat.random(in: 2...6))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 1)
                }
            }

            // Gradient overlay
            LinearGradient(
                colors: [
                    Theme.sun.opacity(0.05),
                    Color.clear,
                    Theme.lagoon.opacity(0.05)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .onAppear {
            animateStars()
        }
    }

    private func animateStars() {
        for index in 0..<20 {
            let delay = Double.random(in: 0...2)
            let duration = Double.random(in: 2...4)

            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
                starOpacities[index] = CGFloat.random(in: 0.2...0.6)
            }
        }
    }
}

#Preview("Quests") {
    PreviewEnvironment {
        AchievementsView()
    }
}
