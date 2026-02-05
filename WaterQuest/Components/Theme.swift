import SwiftUI

enum Theme {
    // MARK: – Core Palette
    static let night      = Color(red: 0.04, green: 0.06, blue: 0.14)
    static let deepSea    = Color(red: 0.06, green: 0.13, blue: 0.28)
    static let lagoon     = Color(red: 0.20, green: 0.63, blue: 0.82)
    static let coral      = Color(red: 0.98, green: 0.50, blue: 0.42)
    static let mint       = Color(red: 0.42, green: 0.92, blue: 0.72)
    static let sun        = Color(red: 1.00, green: 0.84, blue: 0.36)
    static let lavender   = Color(red: 0.62, green: 0.52, blue: 0.98)
    static let peach      = Color(red: 1.00, green: 0.72, blue: 0.60)

    // MARK: – Semantic Colours
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.60)
    static let textTertiary  = Color.white.opacity(0.36)

    // MARK: – Gradients
    static let background = LinearGradient(
        colors: [deepSea, night],
        startPoint: .top,
        endPoint: .bottom
    )

    static let card = LinearGradient(
        colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glowGradient = LinearGradient(
        colors: [lagoon, mint, lavender],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = LinearGradient(
        colors: [coral, sun, peach],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let heroGradient = LinearGradient(
        colors: [lagoon.opacity(0.8), mint.opacity(0.6), lavender.opacity(0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: – Typography
    /// Display / Hero text — bold rounded for playful energy
    static func displayFont(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    /// Section titles
    static func titleFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// Body copy
    static func bodyFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Captions and labels
    static func captionFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    // MARK: – Glassmorphism Card
    static func glassCard(cornerRadius: CGFloat = 24) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: – View Modifiers

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.15), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(25))
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: – Animated Background Bubbles

struct FloatingBubble: View {
    let size: CGFloat
    let color: Color
    let delay: Double
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .fill(color.opacity(0.15))
            .frame(width: size, height: size)
            .blur(radius: size * 0.3)
            .offset(y: yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: Double.random(in: 3...6)).repeatForever(autoreverses: true).delay(delay)) {
                    yOffset = CGFloat.random(in: -40...40)
                }
                withAnimation(.easeIn(duration: 0.8).delay(delay)) {
                    opacity = 1
                }
            }
    }
}

struct AnimatedMeshBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // Floating orbs for depth
            FloatingBubble(size: 220, color: Theme.lagoon, delay: 0)
                .position(x: 60, y: 180)

            FloatingBubble(size: 180, color: Theme.lavender, delay: 0.5)
                .position(x: 320, y: 400)

            FloatingBubble(size: 140, color: Theme.mint, delay: 1.0)
                .position(x: 200, y: 650)

            FloatingBubble(size: 100, color: Theme.coral, delay: 1.5)
                .position(x: 80, y: 520)
        }
    }
}

// MARK: – Preview Environment

#if DEBUG
struct PreviewEnvironment<Content: View>: View {
    @StateObject private var store = HydrationStore()
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var notifier = NotificationScheduler()
    @StateObject private var locationManager: LocationManager
    @StateObject private var weatherClient: WeatherClient

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        let location = LocationManager()
        _locationManager = StateObject(wrappedValue: location)
        _weatherClient = StateObject(wrappedValue: WeatherClient(locationManager: location))
        self.content = content()
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environmentObject(store)
        .environmentObject(healthKit)
        .environmentObject(notifier)
        .environmentObject(locationManager)
        .environmentObject(weatherClient)
        .preferredColorScheme(.dark)
    }
}
#endif
