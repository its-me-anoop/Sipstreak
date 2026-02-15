import SwiftUI

struct SplashScreenView: View {
    @State private var showContent = false
    @State private var floatMascot = false
    @State private var spinOrbit = false

    var body: some View {
        ZStack {
            AppWaterBackground().ignoresSafeArea()
            ambientGlow
            bottomGlow

            VStack(spacing: 20) {
                Spacer(minLength: 88)

                ZStack {
                    Circle()
                        .fill(Theme.lagoon.opacity(0.15))
                        .frame(width: 164, height: 164)
                        .blur(radius: 2)

                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [Theme.lagoon.opacity(0.9), Theme.mint.opacity(0.8), Theme.lagoon.opacity(0.9)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 154, height: 154)
                        .rotationEffect(.degrees(spinOrbit ? 360 : 0))
                        .opacity(0.9)

                    Circle()
                        .stroke(Theme.mint.opacity(0.35), lineWidth: 1.4)
                        .frame(width: 126, height: 126)
                        .scaleEffect(floatMascot ? 0.98 : 1.04)

                    MascotView(size: 92, animated: true)
                        .offset(y: floatMascot ? -8 : 4)
                        .shadow(color: Theme.lagoon.opacity(0.35), radius: 14, x: 0, y: 8)
                }
                .scaleEffect(showContent ? 1 : 0.84)
                .opacity(showContent ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Thirsty.ai")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .kerning(0.4)
                    Text("Hydration that fits your day")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)

                Spacer()

                VStack(spacing: 10) {
                    SplashLoadingDots()
                    Text("Preparing your hydration world")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 56)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                floatMascot = true
            }
            withAnimation(.linear(duration: 4.2).repeatForever(autoreverses: false)) {
                spinOrbit = true
            }
        }
    }

    private var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(Theme.lagoon.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: -90, y: -220)
            Circle()
                .fill(Theme.mint.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 36)
                .offset(x: 120, y: -180)
        }
        .allowsHitTesting(false)
    }

    private var bottomGlow: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.lagoon.opacity(0.18), Theme.mint.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 190)
                .blur(radius: 8)
                .padding(.horizontal, 20)
                .padding(.bottom, -28)
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}

private struct SplashLoadingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.28)) { context in
            let active = Int(context.date.timeIntervalSinceReferenceDate * 3) % 3
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.lagoon.opacity(active == index ? 1 : 0.26))
                        .frame(width: active == index ? 9 : 7, height: active == index ? 9 : 7)
                        .animation(.easeInOut(duration: 0.2), value: active)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Splash") {
    PreviewEnvironment {
        SplashScreenView()
    }
}
#endif
