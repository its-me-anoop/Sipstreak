import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration)
    }

    private struct PrimaryButton: View {
        let configuration: Configuration

        var body: some View {
            configuration.label
                .font(Theme.titleFont(size: 16))
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [Theme.lagoon, Theme.mint], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(.black.opacity(0.85))
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .shadow(color: Theme.lagoon.opacity(0.3), radius: configuration.isPressed ? 6 : 12, x: 0, y: 6)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
                .onChange(of: configuration.isPressed) { _, pressed in
                    if pressed {
                        Haptics.impact(.medium)
                    }
                }
        }
    }
}
