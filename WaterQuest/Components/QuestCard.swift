import SwiftUI

struct QuestCard: View {
    var quest: Quest
    var progress: Double

    @State private var isPressed = false
    @State private var showCheckmark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(quest.isCompleted ? Theme.sun.opacity(0.24) : Theme.lagoon.opacity(0.20))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .strokeBorder((quest.isCompleted ? Theme.sun : Theme.lagoon).opacity(0.28), lineWidth: 0.8)
                        )

                    if quest.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.sunText)
                            .scaleEffect(showCheckmark ? 1 : 0)
                    } else {
                        Image(systemName: questIcon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.lagoon)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title)
                        .font(Theme.titleFont(size: 15))
                        .foregroundColor(Theme.textPrimary)
                        .strikethrough(quest.isCompleted, color: Theme.textTertiary)

                    Text(quest.detail)
                        .font(Theme.bodyFont(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("+\(quest.rewardXP)")
                        .font(Theme.bodyFont(size: 11))
                        .fontWeight(.semibold)
                }
                .foregroundColor(Theme.sunText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Theme.sun.opacity(0.18))
                        .overlay(
                            Capsule()
                                .strokeBorder(Theme.sun.opacity(0.35), lineWidth: 0.8)
                        )
                )
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.glassBorder.opacity(0.35))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: quest.isCompleted
                                    ? [Theme.sun.opacity(0.8), Theme.sun]
                                    : [Theme.mint.opacity(0.8), Theme.lagoon],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)

                }
            }
            .frame(height: 7)
            .animation(Theme.fluidSpring, value: progress)

            if quest.isCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 12))
                    Text("Mission complete - great work!")
                        .font(Theme.bodyFont(size: 12))
                        .fontWeight(.medium)
                }
                .foregroundColor(Theme.sunText)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.glassLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: quest.isCompleted
                                    ? [Theme.sun.opacity(0.4), Theme.sun.opacity(0.1)]
                                    : [Theme.glassBorder.opacity(0.9), Theme.glassBorder.opacity(0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                )
        )
        .shadow(
            color: quest.isCompleted ? Theme.sun.opacity(0.18) : Theme.shadowColor.opacity(0.72),
            radius: quest.isCompleted ? 10 : 7,
            x: 0,
            y: 4
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(Theme.quickSpring, value: isPressed)
        .animation(Theme.fluidSpring, value: quest.isCompleted)
        .onChange(of: quest.isCompleted) { _, completed in
            if completed {
                withAnimation(Theme.quickSpring.delay(0.1)) {
                    showCheckmark = true
                }
                Haptics.questComplete()
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 12, pressing: { isPressing in
            withAnimation(Theme.quickSpring) { isPressed = isPressing }
        }, perform: {})
    }

    private var questIcon: String {
        let title = quest.title.lowercased()
        if title.contains("morning") || title.contains("early") {
            return "sunrise.fill"
        } else if title.contains("goal") || title.contains("complete") {
            return "target"
        } else if title.contains("streak") {
            return "flame.fill"
        } else if title.contains("drink") || title.contains("water") {
            return "drop.fill"
        }
        return "flag.fill"
    }
}
