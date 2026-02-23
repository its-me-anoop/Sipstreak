import SwiftUI

struct AddIntakeView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var amount: Double = 250
    @State private var note = ""
    @State private var selectedPreset: Int?
    @State private var showSavedBanner = false

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: isRegular ? 14 : 10) {
                    Text("Log Water")
                        .font(isRegular ? .title.weight(.semibold) : .title2.weight(.semibold))
                    Text("Fast, accurate intake tracking with Health integration.")
                        .font(isRegular ? .body : .subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, isRegular ? 10 : 6)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(amount))")
                        .font(.system(size: isRegular ? 56 : 44, weight: .bold, design: .default))
                    Text(store.profile.unitSystem.volumeUnit)
                        .font(isRegular ? .title2 : .title3)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Slider(value: $amount, in: amountRange, step: amountStep)
                    .tint(Theme.lagoon)
                    .onChange(of: amount) {
                        selectedPreset = nil
                    }
            }

            Section("Quick Picks") {
                HStack(spacing: isRegular ? 14 : 8) {
                    ForEach(Array(presetAmounts.enumerated()), id: \.offset) { index, preset in
                        Button {
                            Haptics.selection()
                            selectedPreset = index
                            amount = Double(preset)
                        } label: {
                            VStack(spacing: isRegular ? 4 : 2) {
                                Text("\(preset)")
                                    .font(isRegular ? .title3.weight(.semibold) : .headline)
                                Text(store.profile.unitSystem.volumeUnit)
                                    .font(isRegular ? .subheadline : .caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isRegular ? 6 : 0)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedPreset == index ? Theme.lagoon : nil)
                    }
                }
            }

            Section("Note") {
                TextField("Optional context", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Button {
                    addIntake()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Save Intake")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Log Intake")
        .scrollContentBackground(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
        .overlay(alignment: .top) {
            if showSavedBanner {
                SavedBanner(amount: Int(amount), unit: store.profile.unitSystem.volumeUnit)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSavedBanner)
        .onAppear {
            if amount < amountRange.lowerBound || amount > amountRange.upperBound {
                amount = min(max(amount, amountRange.lowerBound), amountRange.upperBound)
            }
        }
    }

    private var amountRange: ClosedRange<Double> {
        store.profile.unitSystem == .metric ? 100...1200 : 4...40
    }

    private var amountStep: Double {
        store.profile.unitSystem == .metric ? 25 : 1
    }

    private var presetAmounts: [Int] {
        store.profile.unitSystem == .metric ? [200, 350, 500, 750] : [8, 12, 16, 24]
    }

    private func addIntake() {
        Haptics.splash()

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = store.addIntake(amount: amount, source: .manual, note: trimmed.isEmpty ? nil : trimmed)

        Task {
            await healthKit.saveWaterIntake(ml: entry.volumeML, date: entry.date, entryID: entry.id)
        }

        withAnimation {
            showSavedBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation {
                showSavedBanner = false
            }
        }

        note = ""
        selectedPreset = nil
    }
}

private struct SavedBanner: View {
    let amount: Int
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.mint)
            Text("Logged \(amount) \(unit)")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
        .shadow(color: Theme.shadowColor, radius: 8, x: 0, y: 4)
    }
}

#Preview("Add Intake") {
    PreviewEnvironment {
        AddIntakeView()
    }
}
