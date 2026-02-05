import SwiftUI

struct MascotView: View {
    @State private var bounce = false

    var body: some View {
        ZStack {
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(Theme.lagoon)
                .shadow(color: Theme.lagoon.opacity(0.4), radius: 12, x: 0, y: 6)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 6, height: 6)
                }
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 18, height: 5)
            }
            .offset(y: 8)
        }
        .frame(width: 80, height: 100)
        .scaleEffect(bounce ? 1.04 : 1.0)
        .offset(y: bounce ? -3 : 0)
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: bounce)
        .onAppear {
            bounce = true
        }
    }
}
