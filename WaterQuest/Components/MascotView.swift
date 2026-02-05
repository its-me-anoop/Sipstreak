import SwiftUI

struct MascotView: View {
    var size: CGFloat = 80
    var animated: Bool = true

    @State private var bounceOffset: CGFloat = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var eyeBlink: Bool = false
    @State private var mouthWidth: CGFloat = 18

    var body: some View {
        ZStack {
            // Glow ring
            if animated {
                Circle()
                    .fill(Theme.lagoon.opacity(0.12))
                    .frame(width: size * 1.6, height: size * 1.6)
                    .scaleEffect(glowScale)
                    .blur(radius: 12)
            }

            // Drop body
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.lagoon, Theme.mint.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Theme.lagoon.opacity(0.5), radius: 16, x: 0, y: 8)
                .frame(width: size, height: size * 1.25)

            // Face
            VStack(spacing: size * 0.06) {
                // Eyes
                HStack(spacing: size * 0.12) {
                    eye
                    eye
                }

                // Mouth — happy little curve
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: mouthWidth, height: size * 0.045)
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: mouthWidth * 0.6, height: size * 0.03)
                            .offset(y: size * 0.015)
                    )
            }
            .offset(y: size * 0.12)

            // Sparkle highlights
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: -size * 0.15, y: -size * 0.15)

            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.05)
                .offset(x: -size * 0.08, y: -size * 0.22)
        }
        .offset(y: bounceOffset)
        .onAppear {
            guard animated else { return }
            // Gentle bob
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                bounceOffset = -8
            }
            // Pulse glow
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowScale = 1.15
            }
            // Blink loop
            startBlinking()
        }
    }

    private var eye: some View {
        ZStack {
            // Eye white
            Capsule()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.09, height: eyeBlink ? size * 0.02 : size * 0.09)
            // Pupil
            if !eyeBlink {
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: size * 0.055, height: size * 0.055)
                    .offset(y: size * 0.005)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: eyeBlink)
    }

    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            eyeBlink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                eyeBlink = false
            }
        }
    }
}

// MARK: – Large Hero Mascot for Onboarding

struct HeroMascotView: View {
    @State private var appear = false
    @State private var ripple1: CGFloat = 0.6
    @State private var ripple2: CGFloat = 0.4
    @State private var ripple1Opacity: Double = 0.3
    @State private var ripple2Opacity: Double = 0.25

    var body: some View {
        ZStack {
            // Water ripples
            Circle()
                .stroke(Theme.lagoon.opacity(ripple1Opacity), lineWidth: 2)
                .frame(width: 200, height: 200)
                .scaleEffect(ripple1)

            Circle()
                .stroke(Theme.mint.opacity(ripple2Opacity), lineWidth: 1.5)
                .frame(width: 200, height: 200)
                .scaleEffect(ripple2)

            MascotView(size: 120, animated: true)
                .scaleEffect(appear ? 1 : 0.5)
                .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                appear = true
            }
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) {
                ripple1 = 1.4
                ripple1Opacity = 0
            }
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false).delay(1.2)) {
                ripple2 = 1.3
                ripple2Opacity = 0
            }
        }
    }
}
