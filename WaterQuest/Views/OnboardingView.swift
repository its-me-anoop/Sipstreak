import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var locationManager: LocationManager

    var onComplete: () -> Void

    @State private var step = 0

    @State private var name = ""
    @State private var unitSystem: UnitSystem = .metric
    @State private var weight: Double = 70
    @State private var activityLevel: ActivityLevel = .steady

    @State private var customGoalEnabled = false
    @State private var customGoalValue: Double = 2200
    @State private var wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var sleepTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var remindersEnabled = true
    @State private var reminderCount = 7

    @State private var prefersWeather = true
    @State private var prefersHealthKit = true

    private let totalSteps = 4

    var body: some View {
        ZStack {
            AppWaterBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                progressHeader
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    profileStep.tag(1)
                    routineStep.tag(2)
                    permissionsStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.36, dampingFraction: 0.88), value: step)

                navigationBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(Theme.lagoon)

            Text("Step \(step + 1) of \(totalSteps)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var welcomeStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 30)

                Image(systemName: "drop.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(Theme.lagoon)
                    .frame(width: 120, height: 120)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )

                VStack(spacing: 10) {
                    Text("Welcome to WaterQuest")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("Build a hydration routine with smart goals, simple logging, and daily momentum.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }

                VStack(alignment: .leading, spacing: 12) {
                    OnboardingFeatureRow(icon: "target", text: "Personal goals based on your profile")
                    OnboardingFeatureRow(icon: "bell.fill", text: "Reminders scheduled around your day")
                    OnboardingFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Progress insights and streak tracking")
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.glassBorder, lineWidth: 1)
                )

                Spacer(minLength: 20)
            }
            .padding(24)
        }
    }

    private var profileStep: some View {
        Form {
            Section("Basics") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)

                Picker("Units", selection: $unitSystem) {
                    Text("Metric").tag(UnitSystem.metric)
                    Text("Imperial").tag(UnitSystem.imperial)
                }
                .pickerStyle(.segmented)
            }

            Section("Body") {
                HStack {
                    Text("Weight")
                    Spacer()
                    Text("\(Int(weight)) \(unitSystem.bodyWeightUnit)")
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: $weight,
                    in: unitSystem == .metric ? 40...140 : 90...300,
                    step: unitSystem == .metric ? 1 : 2
                )
                .tint(Theme.lagoon)

                Picker("Activity", selection: $activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private var routineStep: some View {
        Form {
            Section("Goal") {
                Toggle("Use custom daily goal", isOn: $customGoalEnabled)

                if customGoalEnabled {
                    HStack {
                        Text("Target")
                        Spacer()
                        Text("\(Int(customGoalValue)) \(unitSystem.volumeUnit)")
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $customGoalValue,
                        in: unitSystem == .metric ? 1500...4500 : 50...150,
                        step: unitSystem == .metric ? 50 : 2
                    )
                    .tint(Theme.sun)
                }
            }

            Section("Daily Schedule") {
                DatePicker("Wake", selection: $wakeTime, displayedComponents: .hourAndMinute)
                DatePicker("Sleep", selection: $sleepTime, displayedComponents: .hourAndMinute)
            }

            Section("Reminders") {
                Toggle("Enable reminders", isOn: $remindersEnabled)

                if remindersEnabled {
                    Stepper(value: $reminderCount, in: 3...12) {
                        HStack {
                            Text("Reminders per day")
                            Spacer()
                            Text("\(reminderCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private var permissionsStep: some View {
        Form {
            Section("Smart Features") {
                Toggle("Weather-based goal adjustments", isOn: $prefersWeather)
                Toggle("Workout-based goal adjustments", isOn: $prefersHealthKit)
            }

            Section("Permissions") {
                permissionButton(
                    title: "Connect HealthKit",
                    icon: "heart.fill",
                    tint: Theme.coral,
                    subtitle: healthKit.isAuthorized ? "Connected" : "Optional: used for workouts and water sync"
                ) {
                    Task { await healthKit.requestAuthorization() }
                }

                permissionButton(
                    title: "Allow Location",
                    icon: "location.fill",
                    tint: Theme.sun,
                    subtitle: locationSubtitle
                ) {
                    locationManager.requestPermission()
                }

                permissionButton(
                    title: "Allow Notifications",
                    icon: "bell.badge.fill",
                    tint: Theme.lagoon,
                    subtitle: notificationSubtitle
                ) {
                    Task { await notifier.requestAuthorization() }
                }
            }

            Section {
                Text("You can change any of these settings later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private var navigationBar: some View {
        HStack {
            if step > 0 {
                Button("Back") {
                    Haptics.selection()
                    withAnimation {
                        step -= 1
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button(step == totalSteps - 1 ? "Start" : "Continue") {
                Haptics.impact(.medium)
                if step == totalSteps - 1 {
                    finishOnboarding()
                } else {
                    withAnimation {
                        step += 1
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var locationSubtitle: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "Enabled"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Optional: needed for local weather"
        @unknown default:
            return "Unknown"
        }
    }

    private var notificationSubtitle: String {
        switch notifier.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Enabled"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Optional: used for hydration reminders"
        @unknown default:
            return "Unknown"
        }
    }

    private func permissionButton(
        title: String,
        icon: String,
        tint: Color,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func finishOnboarding() {
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightKg = unitSystem.kg(from: weight)
        let customGoalML = customGoalEnabled ? unitSystem.ml(from: customGoalValue) : nil

        store.updateProfile { profile in
            profile.name = finalName
            profile.unitSystem = unitSystem
            profile.weightKg = weightKg
            profile.activityLevel = activityLevel
            profile.customGoalML = customGoalML
            profile.remindersEnabled = remindersEnabled
            profile.wakeMinutes = minutes(from: wakeTime)
            profile.sleepMinutes = minutes(from: sleepTime)
            profile.dailyReminderCount = reminderCount
            profile.prefersWeatherGoal = prefersWeather
            profile.prefersHealthKit = prefersHealthKit
        }

        if remindersEnabled {
            notifier.scheduleReminders(profile: store.profile)
        }

        onComplete()
    }

    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.lagoon)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

#Preview("Onboarding") {
    PreviewEnvironment {
        OnboardingView { }
    }
}
