import SwiftUI

struct AchievementCelebrationView: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var animateIn = false
    @State private var floatBadge = false
    @State private var triggerConfetti = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            ZStack {
                ConfettiBurstView(trigger: triggerConfetti)

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Theme.sun, Theme.coral], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 88, height: 88)
                            .shadow(color: Theme.sun.opacity(0.5), radius: 16, x: 0, y: 8)

                        FloatingSparklesView()

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.black.opacity(0.8))
                    }
                    .offset(y: floatBadge ? -4 : 4)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: floatBadge)

                    VStack(spacing: 6) {
                        Text("Achievement Unlocked!")
                            .font(Theme.titleFont(size: 20))
                            .foregroundColor(.white)
                        Text(achievement.title)
                            .font(Theme.titleFont(size: 24))
                            .foregroundColor(Theme.sun)
                        Text(achievement.detail)
                            .font(Theme.bodyFont(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                        Text(encouragementLine)
                            .font(Theme.bodyFont(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .multilineTextAlignment(.center)

                    Button("Keep the Flow Going") {
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.12))
                        )
                )
                .padding(.horizontal, 28)
                .scaleEffect(animateIn ? 1 : 0.88)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.78), value: animateIn)
            }
        }
        .onAppear {
            animateIn = true
            floatBadge = true
            triggerConfetti = true
            Haptics.success()
        }
        .accessibilityAddTraits(.isModal)
    }

    private var encouragementLine: String {
        let lines = [
            "You’re building a great habit. Keep it up!",
            "That’s a hydration win. You’ve got this!",
            "Every sip counts—your streak is glowing."
        ]
        let index = abs(achievement.id.hashValue) % lines.count
        return lines[index]
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            onDismiss()
        }
    }
}

private struct FloatingSparklesView: View {
    @State private var twinkle = false

    var body: some View {
        ZStack {
            sparkle(at: CGPoint(x: -26, y: -20), size: 10)
            sparkle(at: CGPoint(x: 30, y: -14), size: 12)
            sparkle(at: CGPoint(x: -18, y: 28), size: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                twinkle = true
            }
        }
    }

    private func sparkle(at point: CGPoint, size: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundColor(.white.opacity(0.85))
            .scaleEffect(twinkle ? 1.0 : 0.6)
            .opacity(twinkle ? 1.0 : 0.4)
            .offset(x: point.x, y: point.y)
    }
}

private struct ConfettiBurstView: View {
    let trigger: Bool

    private let colors: [Color] = [Theme.sun, Theme.coral, Theme.lagoon, Theme.mint]

    var body: some View {
        ZStack {
            if trigger {
                ForEach(0..<18, id: \.self) { index in
                    ConfettiPiece(
                        color: colors[index % colors.count],
                        angle: Double(index) * (2.0 * .pi / 18.0),
                        distance: 60 + Double((index % 6) * 8),
                        delay: Double(index) * 0.02
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiPiece: View {
    let color: Color
    let angle: Double
    let distance: Double
    let delay: Double

    @State private var burst = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 8, height: 12)
            .rotationEffect(.degrees(burst ? 180 : 0))
            .offset(
                x: burst ? cos(angle) * distance : 0,
                y: burst ? sin(angle) * distance : 0
            )
            .opacity(burst ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).delay(delay)) {
                    burst = true
                }
            }
    }
}
