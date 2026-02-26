import SwiftUI

// MARK: - Theme Transition Coordinator

/// Coordinates theme switching with a ripple reveal effect.
/// Captures a screenshot of the current theme, switches underneath,
/// then fades out the old screenshot with a ripple distortion.
@MainActor
final class ThemeTransitionCoordinator: ObservableObject {
    @Published var snapshot: UIImage?
    @Published var origin: CGPoint = .zero
    @Published var rippleTrigger: Int = 0
    @Published var opacity: Double = 1

    private let animationDuration: TimeInterval = 0.8

    func startTransition(from origin: CGPoint, applyTheme: @escaping () -> Void) {
        guard snapshot == nil else { return }

        guard let window = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .windows
            .first(where: \.isKeyWindow) else {
            applyTheme()
            return
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }

        self.snapshot = image
        self.origin = origin
        self.opacity = 1

        // Switch the real theme underneath
        applyTheme()

        // Trigger the ripple and fade out the snapshot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.rippleTrigger += 1

            withAnimation(.easeIn(duration: self.animationDuration)) {
                self.opacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + self.animationDuration + 0.1) {
                self.snapshot = nil
                self.opacity = 1
            }
        }
    }
}

// MARK: - Theme Transition Overlay

struct ThemeTransitionOverlay: View {
    @EnvironmentObject private var coordinator: ThemeTransitionCoordinator

    var body: some View {
        if let snapshot = coordinator.snapshot {
            GeometryReader { geo in
                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .modifier(RippleEffect(at: coordinator.origin, trigger: coordinator.rippleTrigger))
                    .opacity(coordinator.opacity)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            .transition(.identity)
        }
    }
}

// MARK: - View Extension

extension View {
    func themeTransitionOverlay(coordinator: ThemeTransitionCoordinator) -> some View {
        self
            .environmentObject(coordinator)
            .overlay {
                ThemeTransitionOverlay()
                    .environmentObject(coordinator)
            }
    }
}
