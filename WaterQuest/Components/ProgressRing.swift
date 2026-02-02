import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Theme.sun, Theme.coral, Theme.lagoon]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
    }
}
