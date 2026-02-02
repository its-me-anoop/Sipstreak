import SwiftUI

struct StatPill: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.bodyFont(size: 12))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(Theme.titleFont(size: 18))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.card)
        )
    }
}
