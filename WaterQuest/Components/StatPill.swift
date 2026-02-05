import SwiftUI

struct StatPill: View {
    var label: String
    var value: String
    var icon: String? = nil
    var accentColor: Color = Theme.lagoon

    @State private var animatedValue: String = ""

    var body: some View {
        HStack(spacing: 10) {
            if let iconName = icon {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(Theme.bodyFont(size: 11))
                    .foregroundColor(Theme.textTertiary)

                Text(animatedValue)
                    .font(Theme.titleFont(size: 16))
                    .foregroundColor(Theme.textPrimary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.liquidGlassGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Theme.glassBorder, Theme.glassBorder.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        .onAppear {
            animatedValue = value
        }
        .onChange(of: value) { _, newValue in
            withAnimation(Theme.fluidSpring) {
                animatedValue = newValue
            }
        }
    }
}
