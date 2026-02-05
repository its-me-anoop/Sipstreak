import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.titleFont(size: 17))
            .padding(.vertical, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 32)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Theme.lagoon, Theme.mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    // Inner highlight
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .foregroundColor(.black.opacity(0.85))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(color: Theme.lagoon.opacity(configuration.isPressed ? 0.15 : 0.35), radius: configuration.isPressed ? 6 : 16, x: 0, y: configuration.isPressed ? 3 : 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyFont(size: 15))
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .foregroundColor(.white.opacity(0.8))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlowingIconButton: View {
    let icon: String
    let label: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isActive ? 0.25 : 0.10))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isActive ? color : .white.opacity(0.6))
                }

                Text(label)
                    .font(Theme.bodyFont(size: 15))
                    .foregroundColor(.white)

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(isActive ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isActive ? color.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .animation(.spring(response: 0.3), value: isActive)
        }
        .buttonStyle(.plain)
    }
}
