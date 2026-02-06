import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

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
    @State private var showPaywall = false

    private let totalSteps = 4

    var body: some View {
        ZStack {
            AppWaterBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $step) {
                    welcomePage.tag(0)
                    profilePage.tag(1)
                    routinePage.tag(2)
                    permissionsPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.35, dampingFraction: 0.86), value: step)

                footer
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isDismissible: true)
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                if step > 0 {
                    Button("Back") {
                        Haptics.selection()
                        withAnimation {
                            step -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button(step == totalSteps - 1 ? "Get Started" : "Continue") {
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
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }

    private var welcomePage: some View {
        VStack(spacing: 0) {
            OnboardingHero(
                title: "Welcome to WaterQuest",
                subtitle: "Build a healthy hydration routine with clear goals, simple logging, and daily momentum.",
                coverImageName: "OnboardingWelcomeCover"
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    onboardingCard {
                        featureRow(
                            icon: "target",
                            title: "Personal daily goal",
                            subtitle: "Set a target based on your profile and routine."
                        )
                        featureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Progress insights",
                            subtitle: "Track trends and milestones over time."
                        )
                        featureRow(
                            icon: "bell.badge.fill",
                            title: "Smart reminders",
                            subtitle: "Get nudges around your schedule."
                        )
                    }

                    onboardingCard {
                        Label("You can change every setting later in Settings.", systemImage: "slider.horizontal.3")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var profilePage: some View {
        VStack(spacing: 0) {
            OnboardingHero(
                title: "Your Profile",
                subtitle: "A few details help WaterQuest personalize your daily hydration plan.",
                coverImageName: "OnboardingProfileCover"
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    onboardingCard(title: "Basics") {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField("Your name", text: $name)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(uiColor: .systemBackground))
                                )

                            Picker("Units", selection: $unitSystem) {
                                Text("Metric").tag(UnitSystem.metric)
                                Text("Imperial").tag(UnitSystem.imperial)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    onboardingCard(title: "Body") {
                        VStack(alignment: .leading, spacing: 14) {
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
                            .pickerStyle(.menu)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var routinePage: some View {
        VStack(spacing: 0) {
            OnboardingHero(
                title: "Build Your Routine",
                subtitle: "Customize your goal, wake/sleep window, and reminder cadence.",
                coverImageName: "OnboardingRoutineCover"
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    onboardingCard(title: "Daily Goal") {
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

                    onboardingCard(title: "Daily Schedule") {
                        VStack(spacing: 12) {
                            DatePicker("Wake", selection: $wakeTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                            DatePicker("Sleep", selection: $sleepTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                        }
                    }

                    onboardingCard(title: "Reminders") {
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var permissionsPage: some View {
        VStack(spacing: 0) {
            OnboardingHero(
                title: "Smart Features",
                subtitle: "Choose advanced options and permissions. You can always update these later.",
                coverImageName: "OnboardingSmartCover"
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    onboardingCard(title: "Adaptive Goals") {
                        if subscriptionManager.hasActiveSubscription {
                            Toggle("Weather-based goal adjustments", isOn: $prefersWeather)
                            Toggle("Workout-based goal adjustments", isOn: $prefersHealthKit)
                        } else {
                            lockedProRow(
                                title: "Weather-based adjustments",
                                subtitle: "Use local weather for adaptive goals."
                            )
                            lockedProRow(
                                title: "Workout-based adjustments",
                                subtitle: "Use HealthKit workouts for adaptive goals."
                            )
                        }
                    }

                    onboardingCard(title: "Permissions") {
                        if subscriptionManager.hasActiveSubscription {
                            permissionButton(
                                title: "Connect HealthKit",
                                icon: "heart.fill",
                                tint: Theme.coral,
                                subtitle: healthKit.isAuthorized ? "Connected" : "Optional: used for workouts and water sync"
                            ) {
                                Task { await healthKit.requestAuthorization() }
                            }
                        } else {
                            lockedProRow(
                                title: "Connect HealthKit",
                                subtitle: "Premium feature. Start a trial or subscribe to connect."
                            )
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private func onboardingCard<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Theme.lagoon)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
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

    private func lockedProRow(title: String, subtitle: String) -> some View {
        Button {
            Haptics.selection()
            showPaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.sun)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(title) (Pro)")
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
            profile.prefersWeatherGoal = subscriptionManager.hasActiveSubscription ? prefersWeather : false
            profile.prefersHealthKit = subscriptionManager.hasActiveSubscription ? prefersHealthKit : false
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

private struct OnboardingHero: View {
    let title: String
    let subtitle: String
    let coverImageName: String?

    var body: some View {
        VStack(spacing: 16) {
            OnboardingHeroCover(
                imageName: coverImageName
            )

            VStack(spacing: 8) {
                Text(title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingHeroCover: View {
    let imageName: String?

    var body: some View {
        Group {
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(uiColor: .secondarySystemBackground),
                                Color(uiColor: .tertiarySystemBackground)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipped()
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
        }
    }
}

#Preview("Onboarding") {
    PreviewEnvironment {
        OnboardingView { }
    }
}
