import SwiftUI

enum MascotStyle: String, CaseIterable, Identifiable {
    case ripple
    case blaze
    case leafy
    case bolt
    case frost

    var id: String { rawValue }

    var isPremium: Bool {
        self != .ripple
    }

    var name: String {
        switch self {
        case .ripple: return "Ripple"
        case .blaze: return "Blaze"
        case .leafy: return "Leafy"
        case .bolt: return "Bolt"
        case .frost: return "Frost"
        }
    }

    var tagline: String {
        switch self {
        case .ripple: return "Classic aqua companion"
        case .blaze: return "Fiery streak booster"
        case .leafy: return "Fresh and balanced"
        case .bolt: return "Lightning quick energy"
        case .frost: return "Cool and collected"
        }
    }

    var colors: [Color] {
        switch self {
        case .ripple: return [Theme.lagoon, Theme.mint]
        case .blaze: return [Theme.coral, Theme.sun]
        case .leafy: return [Theme.mint, Theme.lagoon]
        case .bolt: return [Theme.lavender, Theme.lagoon]
        case .frost: return [Theme.lagoon.opacity(0.7), Theme.lavender]
        }
    }

    var hueRotation: Double {
        switch self {
        case .ripple: return 0
        case .blaze: return 28
        case .leafy: return -20
        case .bolt: return 45
        case .frost: return -45
        }
    }

    static func from(id: String) -> MascotStyle {
        MascotStyle(rawValue: id) ?? .ripple
    }

    static func sanitizedSelectionID(from id: String, isPro: Bool) -> String {
        let style = from(id: id)
        if style.isPremium && !isPro {
            return MascotStyle.ripple.rawValue
        }
        return style.rawValue
    }
}

struct MascotMask: View {
    let style: MascotStyle

    var body: some View {
        switch style {
        case .ripple:
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
        case .blaze:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .rotation(.degrees(8))
        case .leafy:
            Capsule(style: .continuous)
                .rotation(.degrees(-18))
        case .bolt:
            DiamondShape()
        case .frost:
            HexagonShape()
        }
    }
}

struct MascotView: View {
    var size: CGFloat = 80
    var animated: Bool = true
    var style: MascotStyle? = nil

    @AppStorage("WaterQuest.selectedMascot") private var selectedMascotID: String = MascotStyle.ripple.rawValue

    @State private var bounceOffset: CGFloat = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var eyeBlink: Bool = false
    @State private var mouthWidth: CGFloat = 18

    private var resolvedStyle: MascotStyle {
        style ?? MascotStyle.from(id: selectedMascotID)
    }

    var body: some View {
        let mascotWidth = size
        let mascotHeight = size * 1.25

        ZStack {
            // Glow ring
            if animated {
                Circle()
                    .fill(Theme.lagoon.opacity(0.12))
                    .frame(width: size * 1.6, height: size * 1.6)
                    .scaleEffect(glowScale)
                    .blur(radius: 12)
            }

            // Body
            mascotGradient
                .frame(width: mascotWidth, height: mascotHeight)
                .mask(
                    MascotMask(style: resolvedStyle)
                        .frame(width: mascotWidth, height: mascotHeight)
                )
                .shadow(color: Theme.lagoon.opacity(0.5), radius: 16, x: 0, y: 8)

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

    private var mascotGradient: some View {
        LinearGradient(
            colors: resolvedStyle.colors,
            startPoint: .top,
            endPoint: .bottom
        )
        .hueRotation(.degrees(resolvedStyle.hueRotation))
    }

    private var eye: some View {
        let eyeHeight = eyeBlink ? size * 0.035 : size * 0.09
        let pupilOpacity: Double = eyeBlink ? 0.75 : 1
        let pupilSize = eyeBlink ? size * 0.04 : size * 0.055

        return Capsule(style: .continuous)
            .fill(Color.white.opacity(0.9))
            .frame(width: size * 0.09, height: eyeHeight)
            .overlay {
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: pupilSize, height: pupilSize)
                    .scaleEffect(x: 1, y: eyeBlink ? 0.45 : 1)
                    .opacity(pupilOpacity)
            }
            .clipShape(Capsule(style: .continuous))
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

struct MascotProgressView: View {
    let progress: Double
    var size: CGFloat = 110
    var style: MascotStyle? = nil

    @AppStorage("WaterQuest.selectedMascot") private var selectedMascotID: String = MascotStyle.ripple.rawValue

    @State private var bobOffset: CGFloat = 0
    @State private var glowScale: CGFloat = 1
    @State private var blink: Bool = false

    private var clampedProgress: CGFloat {
        min(1, max(0, progress))
    }

    private var happiness: CGFloat {
        0.2 + (0.8 * clampedProgress)
    }

    private var resolvedStyle: MascotStyle {
        style ?? MascotStyle.from(id: selectedMascotID)
    }

    var body: some View {
        let dropWidth = size
        let dropHeight = size * 1.25
        let mask = MascotMask(style: resolvedStyle)
            .frame(width: dropWidth, height: dropHeight)

        ZStack {
            Circle()
                .fill(Theme.lagoon.opacity(0.12))
                .frame(width: size * 1.4, height: size * 1.4)
                .scaleEffect(glowScale)
                .blur(radius: 14)

            Rectangle()
                .fill(backgroundTint)
                .frame(width: dropWidth, height: dropHeight)
                .mask(mask)

            mascotGradient
                .frame(width: dropWidth, height: dropHeight * clampedProgress, alignment: .bottom)
                .frame(width: dropWidth, height: dropHeight, alignment: .bottom)
                .clipped()
                .mask(mask)

            MascotFaceView(size: size * 0.55, happiness: happiness, blink: blink)
                .offset(y: size * 0.18)
        }
        .offset(y: bobOffset)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                bobOffset = -6
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glowScale = 1.1
            }
            startBlinking()
        }
        .animation(.easeInOut(duration: 0.5), value: clampedProgress)
    }

    private var mascotGradient: some View {
        LinearGradient(
            colors: resolvedStyle.colors,
            startPoint: .top,
            endPoint: .bottom
        )
        .hueRotation(.degrees(resolvedStyle.hueRotation))
    }

    private var backgroundTint: Color {
        (resolvedStyle.colors.first ?? Theme.lagoon).opacity(0.18)
    }

    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 3.8, repeats: true) { _ in
            blink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                blink = false
            }
        }
    }
}

private struct MascotFaceView: View {
    let size: CGFloat
    let happiness: CGFloat
    var blink: Bool = false

    private var eyeScaleY: CGFloat {
        blink ? 0.24 : 0.62 + (0.45 * happiness)
    }

    private var mouthCurvature: CGFloat {
        -0.35 + (0.85 * happiness)
    }

    private var faceOffsetY: CGFloat {
        (1 - happiness) * size * 0.035
    }

    private var eyeOffsetY: CGFloat {
        let expressionLift = (0.5 - happiness) * size * 0.07
        let blinkDip = blink ? size * 0.01 : 0
        return expressionLift + blinkDip
    }

    var body: some View {
        VStack(spacing: size * 0.16) {
            HStack(spacing: size * 0.28) {
                eye
                eye
            }
            .offset(y: eyeOffsetY)

            MascotMouthShape(curvature: mouthCurvature)
                .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
                .frame(width: size * 0.55, height: size * 0.28)
                .shadow(color: Color.white.opacity(0.4), radius: 2, x: 0, y: 1)
        }
        .offset(y: faceOffsetY)
        .animation(.easeInOut(duration: 0.12), value: blink)
        .animation(.easeInOut(duration: 0.35), value: happiness)
    }

    private var eye: some View {
        let pupilSize = blink ? size * 0.075 : size * 0.09

        return Capsule(style: .continuous)
            .fill(Color.white.opacity(0.9))
            .frame(width: size * 0.18, height: size * 0.18)
            .scaleEffect(x: 1, y: eyeScaleY)
            .overlay(
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: pupilSize, height: pupilSize)
                    .scaleEffect(x: 1, y: blink ? 0.45 : 1)
                    .opacity(blink ? 0.75 : 1)
            )
            .clipShape(Capsule(style: .continuous))
    }
}

private struct MascotMouthShape: Shape {
    var curvature: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let end = CGPoint(x: rect.maxX, y: rect.midY)
        let control = CGPoint(x: rect.midX, y: rect.midY + curvature * rect.height)
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

// MARK: – Large Hero Mascot for Onboarding

struct HeroMascotView: View {
    @State private var appear = false
    @State private var ripple1: CGFloat = 0.6
    @State private var ripple2: CGFloat = 0.4
    @State private var ripple3: CGFloat = 0.5
    @State private var ripple1Opacity: Double = 0.3
    @State private var ripple2Opacity: Double = 0.25
    @State private var ripple3Opacity: Double = 0.2
    @State private var sparkleRotation: Double = 0

    var body: some View {
        ZStack {
            // Three layered water ripples
            Circle()
                .stroke(Theme.lagoon.opacity(ripple1Opacity), lineWidth: 2)
                .frame(width: 220, height: 220)
                .scaleEffect(ripple1)

            Circle()
                .stroke(Theme.mint.opacity(ripple2Opacity), lineWidth: 1.5)
                .frame(width: 220, height: 220)
                .scaleEffect(ripple2)

            Circle()
                .stroke(Theme.lavender.opacity(ripple3Opacity), lineWidth: 1)
                .frame(width: 220, height: 220)
                .scaleEffect(ripple3)

            // Orbiting sparkle particles
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 3, height: 3)
                    .offset(y: -100)
                    .rotationEffect(.degrees(Double(i) * 60 + sparkleRotation))
            }

            MascotView(size: 120, animated: true)
                .scaleEffect(appear ? 1 : 0.3)
                .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) {
                appear = true
            }
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) {
                ripple1 = 1.5
                ripple1Opacity = 0
            }
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false).delay(0.8)) {
                ripple2 = 1.4
                ripple2Opacity = 0
            }
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false).delay(1.6)) {
                ripple3 = 1.3
                ripple3Opacity = 0
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
        }
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.midY)
        path.move(to: top)
        path.addLines([right, bottom, left, top])
        return path
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let xOffset = width * 0.1
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + xOffset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - xOffset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - xOffset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + xOffset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
