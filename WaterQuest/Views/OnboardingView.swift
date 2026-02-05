import SwiftUI

// MARK: – Main Onboarding Coordinator

struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var locationManager: LocationManager

    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var direction: TransitionDirection = .forward

    // Page 1 – Profile
    @State private var name = ""
    @State private var unitSystem: UnitSystem = .metric
    @State private var weight: Double = 70
    @State private var activityLevel: ActivityLevel = .steady

    // Page 2 – Schedule
    @State private var customGoalEnabled = false
    @State private var customGoalValue: Double = 2200
    @State private var wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var sleepTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var remindersEnabled = true
    @State private var reminderCount = 7

    // Page 3 – Permissions
    @State private var prefersWeather = true
    @State private var prefersHealthKit = true

    private let totalPages = 4

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                if currentPage > 0 {
                    OnboardingProgressBar(current: currentPage, total: totalPages)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Page content
                ZStack {
                    pageContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Navigation
                navigationBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case 0:
            WelcomePage()
                .transition(pageTransition)
        case 1:
            ProfilePage(
                name: $name,
                unitSystem: $unitSystem,
                weight: $weight,
                activityLevel: $activityLevel
            )
            .transition(pageTransition)
        case 2:
            SchedulePage(
                unitSystem: unitSystem,
                customGoalEnabled: $customGoalEnabled,
                customGoalValue: $customGoalValue,
                wakeTime: $wakeTime,
                sleepTime: $sleepTime,
                remindersEnabled: $remindersEnabled,
                reminderCount: $reminderCount
            )
            .transition(pageTransition)
        case 3:
            PowerUpsPage(
                prefersWeather: $prefersWeather,
                prefersHealthKit: $prefersHealthKit,
                healthKit: healthKit,
                notifier: notifier,
                locationManager: locationManager
            )
            .transition(pageTransition)
        default:
            EmptyView()
        }
    }

    private var pageTransition: AnyTransition {
        switch direction {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            if currentPage > 0 {
                Button {
                    direction = .backward
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        currentPage -= 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Spacer()

            Button {
                if currentPage == totalPages - 1 {
                    finishOnboarding()
                } else {
                    direction = .forward
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        currentPage += 1
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentPage == 0 ? "Let's Go!" : currentPage == totalPages - 1 ? "Begin My Quest" : "Continue")
                    Image(systemName: currentPage == totalPages - 1 ? "sparkles" : "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: false))
        }
    }

    private func finishOnboarding() {
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightKg = unitSystem.kg(from: weight)
        let customGoalML = customGoalEnabled ? unitSystem.ml(from: customGoalValue) : nil
        let wakeMinutes = minutes(from: wakeTime)
        let sleepMinutes = minutes(from: sleepTime)

        store.updateProfile { profile in
            profile.name = finalName
            profile.unitSystem = unitSystem
            profile.weightKg = weightKg
            profile.activityLevel = activityLevel
            profile.customGoalML = customGoalML
            profile.remindersEnabled = remindersEnabled
            profile.wakeMinutes = wakeMinutes
            profile.sleepMinutes = sleepMinutes
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

private enum TransitionDirection {
    case forward, backward
}

// MARK: – Progress Bar

struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Theme.lagoon : Color.white.opacity(0.15))
                    .frame(height: 4)
                    .animation(.spring(response: 0.4), value: current)
            }
        }
    }
}

// MARK: – Page 0: Welcome

struct WelcomePage: View {
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showFeatures = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HeroMascotView()
                .padding(.bottom, 32)

            Text("WaterQuest")
                .font(Theme.displayFont(size: 38))
                .foregroundStyle(Theme.glowGradient)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 20)
                .padding(.bottom, 12)

            Text("Your hydration adventure starts here")
                .font(Theme.bodyFont(size: 17))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .opacity(showSubtitle ? 1 : 0)
                .offset(y: showSubtitle ? 0 : 15)
                .padding(.horizontal, 40)
                .padding(.bottom, 36)

            // Feature pills
            VStack(spacing: 12) {
                featurePill(icon: "target", text: "Smart goals that adapt to your day", color: Theme.lagoon, delay: 0)
                featurePill(icon: "flame.fill", text: "Streaks, quests & rewards", color: Theme.coral, delay: 0.1)
                featurePill(icon: "cloud.sun.fill", text: "Weather-aware hydration", color: Theme.sun, delay: 0.2)
            }
            .opacity(showFeatures ? 1 : 0)
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                showTitle = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
                showSubtitle = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7)) {
                showFeatures = true
            }
        }
    }

    private func featurePill(icon: String, text: String, color: Color, delay: Double) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(text)
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

// MARK: – Page 1: Profile

struct ProfilePage: View {
    @Binding var name: String
    @Binding var unitSystem: UnitSystem
    @Binding var weight: Double
    @Binding var activityLevel: ActivityLevel

    @State private var appear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Who are you,\nadventurer?")
                        .font(Theme.displayFont(size: 30))
                        .foregroundColor(.white)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 20)

                    Text("We'll use this to craft your perfect hydration plan.")
                        .font(Theme.bodyFont(size: 15))
                        .foregroundColor(Theme.textSecondary)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 15)
                }
                .padding(.top, 20)

                // Name field
                OnboardingCard(delay: 0.1, appear: appear) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Your Name", systemImage: "person.fill")
                            .font(Theme.captionFont(size: 13))
                            .foregroundColor(Theme.textSecondary)

                        TextField("What should we call you?", text: $name)
                            .font(Theme.bodyFont(size: 17))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                    }
                }

                // Units
                OnboardingCard(delay: 0.2, appear: appear) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Preferred Units", systemImage: "ruler.fill")
                            .font(Theme.captionFont(size: 13))
                            .foregroundColor(Theme.textSecondary)

                        HStack(spacing: 10) {
                            UnitPill(title: "Metric", subtitle: "ml · kg", isSelected: unitSystem == .metric) {
                                withAnimation(.spring(response: 0.3)) { unitSystem = .metric }
                            }
                            UnitPill(title: "Imperial", subtitle: "oz · lb", isSelected: unitSystem == .imperial) {
                                withAnimation(.spring(response: 0.3)) { unitSystem = .imperial }
                            }
                        }
                    }
                }

                // Weight
                OnboardingCard(delay: 0.3, appear: appear) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Weight", systemImage: "scalemass.fill")
                                .font(Theme.captionFont(size: 13))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(Int(weight)) \(unitSystem.bodyWeightUnit)")
                                .font(Theme.titleFont(size: 22))
                                .foregroundStyle(Theme.glowGradient)
                        }

                        Slider(
                            value: $weight,
                            in: unitSystem == .metric ? 40...140 : 90...300,
                            step: unitSystem == .metric ? 1 : 2
                        )
                        .tint(Theme.lagoon)
                    }
                }

                // Activity
                OnboardingCard(delay: 0.4, appear: appear) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("How active are you?", systemImage: "figure.run")
                            .font(Theme.captionFont(size: 13))
                            .foregroundColor(Theme.textSecondary)

                        HStack(spacing: 10) {
                            ForEach(ActivityLevel.allCases, id: \.self) { level in
                                ActivityPill(level: level, isSelected: activityLevel == level) {
                                    withAnimation(.spring(response: 0.3)) {
                                        activityLevel = level
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}

// MARK: – Page 2: Schedule

struct SchedulePage: View {
    let unitSystem: UnitSystem
    @Binding var customGoalEnabled: Bool
    @Binding var customGoalValue: Double
    @Binding var wakeTime: Date
    @Binding var sleepTime: Date
    @Binding var remindersEnabled: Bool
    @Binding var reminderCount: Int

    @State private var appear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Design your\nroutine")
                        .font(Theme.displayFont(size: 30))
                        .foregroundColor(.white)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 20)

                    Text("We'll send friendly nudges throughout your day so you never forget to sip.")
                        .font(Theme.bodyFont(size: 15))
                        .foregroundColor(Theme.textSecondary)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 15)
                }
                .padding(.top, 20)

                // Custom goal toggle
                OnboardingCard(delay: 0.1, appear: appear) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $customGoalEnabled.animation(.spring(response: 0.3))) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Set a custom daily goal")
                                    .font(Theme.bodyFont(size: 15))
                                    .foregroundColor(.white)
                                Text("Or let us calculate the perfect amount")
                                    .font(Theme.captionFont(size: 12))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.sun))

                        if customGoalEnabled {
                            VStack(spacing: 8) {
                                HStack {
                                    Spacer()
                                    Text("\(Int(customGoalValue)) \(unitSystem.volumeUnit)")
                                        .font(Theme.titleFont(size: 26))
                                        .foregroundStyle(Theme.warmGradient)
                                    Spacer()
                                }
                                Slider(
                                    value: $customGoalValue,
                                    in: unitSystem == .metric ? 1500...4500 : 50...150,
                                    step: unitSystem == .metric ? 50 : 2
                                )
                                .tint(Theme.sun)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                // Wake / Sleep
                OnboardingCard(delay: 0.2, appear: appear) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Your daily rhythm", systemImage: "sunrise.fill")
                            .font(Theme.captionFont(size: 13))
                            .foregroundColor(Theme.textSecondary)

                        HStack(spacing: 14) {
                            StyledTimePicker(title: "Rise & shine", icon: "sunrise.fill", color: Theme.sun, date: $wakeTime)
                            StyledTimePicker(title: "Wind down", icon: "moon.fill", color: Theme.lavender, date: $sleepTime)
                        }
                    }
                }

                // Reminders
                OnboardingCard(delay: 0.3, appear: appear) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $remindersEnabled.animation(.spring(response: 0.3))) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gentle reminders")
                                    .font(Theme.bodyFont(size: 15))
                                    .foregroundColor(.white)
                                Text("Friendly nudges to keep you on track")
                                    .font(Theme.captionFont(size: 12))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.lagoon))

                        if remindersEnabled {
                            HStack {
                                Text("\(reminderCount) reminders per day")
                                    .font(Theme.bodyFont(size: 14))
                                    .foregroundColor(.white)
                                Spacer()
                                Stepper("", value: $reminderCount, in: 3...12)
                                    .labelsHidden()
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}

// MARK: – Page 3: Power-Ups / Permissions

struct PowerUpsPage: View {
    @Binding var prefersWeather: Bool
    @Binding var prefersHealthKit: Bool
    let healthKit: HealthKitManager
    let notifier: NotificationScheduler
    let locationManager: LocationManager

    @State private var appear = false
    @State private var healthGranted = false
    @State private var locationGranted = false
    @State private var notifGranted = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unlock your\npower-ups ⚡")
                        .font(Theme.displayFont(size: 30))
                        .foregroundColor(.white)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 20)

                    Text("These are optional but they make WaterQuest way smarter. You can always change these later.")
                        .font(Theme.bodyFont(size: 15))
                        .foregroundColor(Theme.textSecondary)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 15)
                }
                .padding(.top, 20)

                // Feature toggles
                OnboardingCard(delay: 0.1, appear: appear) {
                    VStack(spacing: 14) {
                        Toggle(isOn: $prefersWeather.animation(.spring(response: 0.3))) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.sun.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "cloud.sun.fill")
                                        .foregroundColor(Theme.sun)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Weather-aware goals")
                                        .font(Theme.bodyFont(size: 15))
                                        .foregroundColor(.white)
                                    Text("Drink more when it's hot")
                                        .font(Theme.captionFont(size: 12))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.sun))

                        Divider().background(Color.white.opacity(0.08))

                        Toggle(isOn: $prefersHealthKit.animation(.spring(response: 0.3))) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.mint.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(Theme.mint)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Health & workout sync")
                                        .font(Theme.bodyFont(size: 15))
                                        .foregroundColor(.white)
                                    Text("Adjust goals after exercise")
                                        .font(Theme.captionFont(size: 12))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.mint))
                    }
                }

                // Permission buttons
                OnboardingCard(delay: 0.2, appear: appear) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Grant access", systemImage: "shield.checkered")
                            .font(Theme.captionFont(size: 13))
                            .foregroundColor(Theme.textSecondary)

                        GlowingIconButton(
                            icon: "heart.fill",
                            label: "Health & Activity",
                            color: Theme.mint,
                            isActive: healthGranted
                        ) {
                            Task {
                                await healthKit.requestAuthorization()
                                healthGranted = healthKit.isAuthorized
                            }
                        }

                        GlowingIconButton(
                            icon: "location.fill",
                            label: "Location for Weather",
                            color: Theme.sun,
                            isActive: locationGranted
                        ) {
                            locationManager.requestPermission()
                            // Observe authorization change
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                let status = locationManager.authorizationStatus
                                locationGranted = (status == .authorizedWhenInUse || status == .authorizedAlways)
                            }
                        }

                        GlowingIconButton(
                            icon: "bell.fill",
                            label: "Notifications",
                            color: Theme.lavender,
                            isActive: notifGranted
                        ) {
                            Task {
                                await notifier.requestAuthorization()
                                notifGranted = (notifier.authorizationStatus == .authorized)
                            }
                        }
                    }
                }

                // Reassurance
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(Theme.textTertiary)
                        .font(.system(size: 14))
                    Text("Your data stays on your device. Always.")
                        .font(Theme.captionFont(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
                .opacity(appear ? 1 : 0)
                .padding(.horizontal, 4)

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}

// MARK: – Reusable Onboarding Components

struct OnboardingCard<Content: View>: View {
    let delay: Double
    let appear: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 25)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: appear)
    }
}

struct UnitPill: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(Theme.titleFont(size: 15))
                    .foregroundColor(isSelected ? .black.opacity(0.85) : .white)
                Text(subtitle)
                    .font(Theme.captionFont(size: 11))
                    .foregroundColor(isSelected ? .black.opacity(0.5) : Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ?
                        AnyShapeStyle(LinearGradient(colors: [Theme.lagoon, Theme.mint], startPoint: .leading, endPoint: .trailing)) :
                        AnyShapeStyle(Color.white.opacity(0.06))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ActivityPill: View {
    let level: ActivityLevel
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch level {
        case .chill: return "leaf.fill"
        case .steady: return "figure.walk"
        case .intense: return "flame.fill"
        }
    }

    private var color: Color {
        switch level {
        case .chill: return Theme.mint
        case .steady: return Theme.lagoon
        case .intense: return Theme.coral
        }
    }

    private var subtitle: String {
        switch level {
        case .chill: return "Relaxed"
        case .steady: return "Moderate"
        case .intense: return "Very active"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color.opacity(0.25) : Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? color : .white.opacity(0.4))
                }
                Text(level.label)
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                Text(subtitle)
                    .font(Theme.captionFont(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? color.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct StyledTimePicker: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12))
                Text(title)
                    .font(Theme.captionFont(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

// MARK: – Previews

#Preview("Onboarding") {
    PreviewEnvironment {
        OnboardingView { }
    }
}
