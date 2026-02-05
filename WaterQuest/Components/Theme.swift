import SwiftUI
import UIKit

// MARK: - App-wide appearance preference
enum AppTheme: String, CaseIterable, RawRepresentable, Identifiable {
    var id: String { rawValue }
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "Automatic"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.half"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.stars.fill"
        }
    }

    /// Maps to the SwiftUI ColorScheme (nil means follow the system).
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum Theme {
    // MARK: - Accent Colors (unchanged across modes)
    static let lagoon = Color(red: 0.20, green: 0.63, blue: 0.82)
    static let coral  = Color(red: 0.98, green: 0.58, blue: 0.48)
    static let mint   = Color(red: 0.58, green: 0.90, blue: 0.78)
    static let sun    = Color(red: 0.98, green: 0.86, blue: 0.46)

    // MARK: - Dark-palette base colors (kept for reuse in gradients)
    static let night   = Color(red: 0.07, green: 0.10, blue: 0.20)
    static let deepSea = Color(red: 0.08, green: 0.18, blue: 0.35)

    // MARK: - Light-palette base colors
    static let daysky  = Color(red: 0.95, green: 0.97, blue: 1.00)
    static let shallow = Color(red: 0.82, green: 0.92, blue: 0.98)

    // MARK: - Adaptive Color Helper
    /// Creates a SwiftUI Color that resolves differently in light and dark mode
    /// by wrapping a UIColor with trait-collection-aware variants.
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor(dynamicProvider: { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }))
    }

    // MARK: - Adaptive Colors
    static let bgPrimary   = adaptive(light: UIColor(red: 0.95, green: 0.97, blue: 1.00, alpha: 1),
                                      dark:  UIColor(red: 0.07, green: 0.10, blue: 0.20, alpha: 1))
    static let bgSecondary = adaptive(light: UIColor(red: 0.82, green: 0.92, blue: 0.98, alpha: 1),
                                      dark:  UIColor(red: 0.08, green: 0.18, blue: 0.35, alpha: 1))

    static let textPrimary   = adaptive(light: UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1),
                                        dark:  UIColor(red: 1.0,  green: 1.0,  blue: 1.0,  alpha: 1))
    static let textSecondary = adaptive(light: UIColor(red: 0.35, green: 0.37, blue: 0.42, alpha: 1),
                                        dark:  UIColor(red: 1.0,  green: 1.0,  blue: 1.0,  alpha: 0.6))
    static let textTertiary  = adaptive(light: UIColor(red: 0.50, green: 0.52, blue: 0.56, alpha: 1),
                                        dark:  UIColor(red: 1.0,  green: 1.0,  blue: 1.0,  alpha: 0.45))

    // MARK: - Liquid Glass Colors (adaptive)
    static let glassLight     = adaptive(light: UIColor(red: 0, green: 0, blue: 0, alpha: 0.07),
                                         dark:  UIColor(red: 1, green: 1, blue: 1, alpha: 0.18))
    static let glassDark      = adaptive(light: UIColor(red: 0, green: 0, blue: 0, alpha: 0.04),
                                         dark:  UIColor(red: 1, green: 1, blue: 1, alpha: 0.06))
    static let glassHighlight = adaptive(light: UIColor(red: 0, green: 0, blue: 0, alpha: 0.10),
                                         dark:  UIColor(red: 1, green: 1, blue: 1, alpha: 0.35))
    static let glassBorder    = adaptive(light: UIColor(red: 0, green: 0, blue: 0, alpha: 0.18),
                                         dark:  UIColor(red: 1, green: 1, blue: 1, alpha: 0.25))
    static let glassAccent    = Color(red: 0.4, green: 0.8, blue: 1.0)

    /// Sun/yellow used as text or icon colour — darkened in light mode for contrast
    static let sunText = adaptive(light: UIColor(red: 0.72, green: 0.56, blue: 0.10, alpha: 1),
                                  dark:  UIColor(red: 0.98, green: 0.86, blue: 0.46, alpha: 1))
    /// Mint/green used as text or icon colour — darkened in light mode for contrast
    static let mintText = adaptive(light: UIColor(red: 0.18, green: 0.62, blue: 0.50, alpha: 1),
                                   dark:  UIColor(red: 0.58, green: 0.90, blue: 0.78, alpha: 1))

    // MARK: - Adaptive Gradients
    /// Main page background gradient — computed so it picks up the resolved adaptive colors each render
    static var background: LinearGradient {
        LinearGradient(
            colors: [bgSecondary, bgPrimary],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var card: LinearGradient {
        LinearGradient(
            colors: [glassLight, glassDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var liquidGlassGradient: LinearGradient {
        LinearGradient(
            colors: [glassLight, glassDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let waterGradient = LinearGradient(
        colors: [lagoon.opacity(0.8), mint.opacity(0.6), deepSea.opacity(0.9)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let progressGlow = RadialGradient(
        colors: [lagoon.opacity(0.6), lagoon.opacity(0.0)],
        center: .center,
        startRadius: 60,
        endRadius: 120
    )

    // MARK: - Fonts
    static func titleFont(size: CGFloat) -> Font {
        .custom("AvenirNextRounded-DemiBold", size: size)
    }

    static func bodyFont(size: CGFloat) -> Font {
        .custom("AvenirNext-Regular", size: size)
    }

    // MARK: - Animation Timings
    static let fluidSpring     = Animation.spring(response: 0.6,  dampingFraction: 0.75, blendDuration: 0.2)
    static let gentleSpring    = Animation.spring(response: 0.8,  dampingFraction: 0.85, blendDuration: 0.3)
    static let quickSpring     = Animation.spring(response: 0.35, dampingFraction: 0.7,  blendDuration: 0.1)
    static let rippleAnimation = Animation.easeInOut(duration: 0.4)
}

#if DEBUG
struct PreviewEnvironment<Content: View>: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .dark
    @StateObject private var store = HydrationStore()
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var notifier = NotificationScheduler()
    @StateObject private var locationManager: LocationManager
    @StateObject private var weatherClient: WeatherClient
    @StateObject private var subscriptionManager = SubscriptionManager()

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        let location = LocationManager()
        let client = WeatherClient(locationManager: location)
        client.currentWeather = .mild
        _locationManager = StateObject(wrappedValue: location)
        _weatherClient = StateObject(wrappedValue: client)
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
        .environmentObject(subscriptionManager)
        .preferredColorScheme(appTheme.colorScheme ?? .dark)
    }
}
#endif
