import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 16
    var showRippleEffect: Bool = true

    @State private var animationTime: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: CGFloat = 0.0

    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Outer glow effect
            Circle()
                .fill(Theme.progressGlow)
                .scaleEffect(1.3)
                .opacity(glowOpacity * progress)

            // Background ring with subtle gradient
            Circle()
                .stroke(
                    Theme.glassBorder.opacity(0.5),
                    lineWidth: lineWidth
                )

            // Water fill effect inside ring
            if showRippleEffect {
                WaterFillCircle(progress: progress, animationTime: animationTime)
                    .mask(
                        Circle()
                            .strokeBorder(lineWidth: lineWidth - 2)
                    )
            }

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Theme.mint,
                            Theme.lagoon,
                            Theme.glassAccent,
                            Theme.lagoon,
                            Theme.mint
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.lagoon.opacity(0.5), radius: 8, x: 0, y: 0)
                .animation(Theme.fluidSpring, value: progress)

            // End cap glow
            if progress > 0.05 {
                Circle()
                    .fill(Theme.glassHighlight)
                    .frame(width: lineWidth * 0.6, height: lineWidth * 0.6)
                    .offset(y: -((lineWidth > 16 ? 80 : 72)))
                    .rotationEffect(.degrees(-90 + 360 * progress))
                    .blur(radius: 2)
                    .scaleEffect(pulseScale)
            }
        }
        .onReceive(timer) { _ in
            animationTime += 0.016
            if animationTime > 1000 { animationTime = 0 }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                glowOpacity = 0.6
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
}

// MARK: - Water Fill Effect
struct WaterFillCircle: View {
    var progress: Double
    var animationTime: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                // Water waves
                ForEach(0..<3, id: \.self) { index in
                    WaterWaveShape(
                        progress: progress,
                        waveHeight: 4 + CGFloat(index) * 2,
                        phase: animationTime * (1.5 + CGFloat(index) * 0.3)
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.lagoon.opacity(0.4 - Double(index) * 0.1),
                                Theme.mint.opacity(0.3 - Double(index) * 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Water Wave Shape
struct WaterWaveShape: Shape {
    var progress: Double
    var waveHeight: CGFloat
    var phase: CGFloat

    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let waterLevel = rect.height * (1 - CGFloat(progress))
        let wavelength = rect.width / 2

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: waterLevel))

        for x in stride(from: 0, through: rect.width, by: 2) {
            let relativeX = x / wavelength
            let y = waterLevel + sin(relativeX * .pi * 2 + phase) * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()

        return path
    }
}
