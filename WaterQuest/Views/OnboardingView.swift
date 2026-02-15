import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @AppStorage("WaterQuest.selectedMascot") private var selectedMascotID: String = MascotStyle.ripple.rawValue

    var onComplete: () -> Void

    @State private var step = 0

    @State private var name = ""
    @State private var unitSystem: UnitSystem = .metric
    @State private var weight: Double = 70
    @State private var activityLevel: ActivityLevel = .steady
    @State private var profileStep = 0
    @State private var routineStep = 0
    @State private var permissionsStep = 2

    @State private var customGoalEnabled = false
    @State private var customGoalValue: Double = 2200
    @State private var wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var sleepTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var remindersEnabled = false
    @State private var reminderCount = 7

    @State private var prefersWeather = false
    @State private var prefersHealthKit = false
    @State private var pendingEnableWeatherAdjustment = false
    @State private var pendingEnableWorkoutAdjustment = false

    @State private var premiumMascotIndex = 0
    @State private var mascotSlideDirection = 1
    @State private var selectedMascotStyle: MascotStyle = .ripple
    @State private var showEndOfOnboardingPaywall = false

    private let totalSteps = 4
    private let onboardingMascotStyles: [MascotStyle] = [.ripple, .blaze, .leafy, .bolt, .frost]

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack {
                AppWaterBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    TabView(selection: $step) {
                        welcomePage(topInset: topInset, bottomInset: bottomInset).tag(0)
                        profilePage(topInset: topInset, bottomInset: bottomInset).tag(1)
                        routinePage(topInset: topInset, bottomInset: bottomInset).tag(2)
                        permissionsPage(topInset: topInset, bottomInset: bottomInset).tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.5, dampingFraction: 0.84), value: step)
                }
                .ignoresSafeArea()
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            let isEnabled = status == .authorizedAlways || status == .authorizedWhenInUse
            if isEnabled {
                if pendingEnableWeatherAdjustment {
                    prefersWeather = true
                }
                pendingEnableWeatherAdjustment = false
            } else {
                if status == .denied || status == .restricted {
                    pendingEnableWeatherAdjustment = false
                }
                prefersWeather = false
            }
        }
        .onChange(of: healthKit.isAuthorized) { _, isAuthorized in
            if isAuthorized {
                if pendingEnableWorkoutAdjustment {
                    prefersHealthKit = true
                }
                pendingEnableWorkoutAdjustment = false
            } else {
                pendingEnableWorkoutAdjustment = false
                prefersHealthKit = false
            }
        }
        .sheet(isPresented: $showEndOfOnboardingPaywall, onDismiss: {
            guard subscriptionManager.isPro else { return }
            finishOnboarding()
        }) {
            PaywallView(isDismissible: false)
        }
    }

    private var adaptiveWeatherBinding: Binding<Bool> {
        Binding(
            get: { prefersWeather },
            set: { newValue in
                if !newValue {
                    pendingEnableWeatherAdjustment = false
                    prefersWeather = false
                    return
                }

                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    pendingEnableWeatherAdjustment = false
                    prefersWeather = false
                    openAppSettings()
                    return
                }

                guard locationPermissionEnabled else {
                    pendingEnableWeatherAdjustment = true
                    prefersWeather = false
                    locationManager.requestPermission()
                    locationManager.requestLocation()
                    return
                }

                pendingEnableWeatherAdjustment = false
                prefersWeather = true
            }
        )
    }

    private var adaptiveWorkoutBinding: Binding<Bool> {
        Binding(
            get: { prefersHealthKit },
            set: { newValue in
                if !newValue {
                    pendingEnableWorkoutAdjustment = false
                    prefersHealthKit = false
                    return
                }

                if healthKit.isPermissionDenied {
                    pendingEnableWorkoutAdjustment = false
                    prefersHealthKit = false
                    openAppSettings()
                    return
                }

                guard healthKit.isAuthorized else {
                    pendingEnableWorkoutAdjustment = true
                    prefersHealthKit = false
                    Task {
                        await healthKit.requestAuthorization()
                        await healthKit.refreshAuthorizationStatus()
                        if pendingEnableWorkoutAdjustment && healthKit.isAuthorized {
                            prefersHealthKit = true
                        }
                        pendingEnableWorkoutAdjustment = false
                    }
                    return
                }

                pendingEnableWorkoutAdjustment = false
                prefersHealthKit = true
            }
        )
    }

    private var footer: some View {
        VStack(spacing: 14) {
            let isFirstStep = step == 0
            let showBack = step > 0

            if isFirstStep {
                Button("Continue") {
                    Haptics.impact(.medium)
                    withAnimation {
                        step += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 240)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack(spacing: 10) {
                    Button("Back") {
                        Haptics.selection()
                        withAnimation {
                            step -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .opacity(showBack ? 1 : 0)
                    .disabled(!showBack)

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
        }
        .padding(.top, 4)
    }

    private func welcomePage(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                StretchableHeader(topSafeAreaInset: topInset) {
                    OnboardingMascotCover(style: .ripple)
                } content: {
                    VStack(spacing: 10) {
                        Text("Welcome to your water buddy")
                            .font(.title.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)

                        Text("We will set up your daily water plan in under a minute.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                VStack(spacing: 18) {
                    onboardingCard {
                        featureRow(
                            icon: "target",
                            title: "Goal made for you",
                            subtitle: "We suggest a daily amount that fits your body and routine."
                        )
                        featureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Simple progress view",
                            subtitle: "See how close you are today and celebrate streaks."
                        )
                        featureRow(
                            icon: "bell.badge.fill",
                            title: "Friendly reminders",
                            subtitle: "Gentle nudges help you stay on track."
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

                footer
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
        }
        .onAppear { profileStep = 0 }
        .contentMargins(.bottom, bottomInset + 44, for: .scrollContent)
        .ignoresSafeArea(edges: .top)
    }

    private func profilePage(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                StretchableHeader(topSafeAreaInset: topInset) {
                    OnboardingMascotCover(style: .leafy)
                } content: {
                    VStack(spacing: 10) {
                        Text("Tell us about you")
                            .font(.title.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)

                        Text("A few quick choices help us build your daily plan.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                VStack(spacing: 18) {
                    if profileStep == 0 {
                        onboardingCard(title: "What should we call you?") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Optional")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("This is optional and only used inside the app.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextField("Your name", text: $name)
                                    .textInputAutocapitalization(.words)
                                    .disableAutocorrection(true)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(uiColor: .systemBackground))
                                    )

                                HStack {
                                    Button("Skip") {
                                        withAnimation { profileStep = 1 }
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()

                                    Button("Next") {
                                        withAnimation { profileStep = 1 }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    } else if profileStep == 1 {
                        onboardingCard(title: "Pick your units") {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("You can switch this later in Settings.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Picker("Units", selection: $unitSystem) {
                                    Text("Metric").tag(UnitSystem.metric)
                                    Text("Imperial").tag(UnitSystem.imperial)
                                }
                                .pickerStyle(.segmented)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Metric: milliliters (ml), kilograms (kg)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Imperial: ounces (oz), pounds (lb)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                HStack {
                                    Button("Back") {
                                        withAnimation { profileStep = 0 }
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()

                                    Button("Next") {
                                        withAnimation { profileStep = 2 }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    } else if profileStep == 2 {
                        onboardingCard(title: "Your weight") {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("We use this to suggest your daily water target.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

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

                                HStack {
                                    Button("Back") {
                                        withAnimation { profileStep = 1 }
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()

                                    Button("Next") {
                                        withAnimation { profileStep = 3 }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    } else {
                        onboardingCard(title: "How active are your days?") {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("This helps us fine-tune your daily target.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Picker("Activity", selection: $activityLevel) {
                                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                                        Text(level.label).tag(level)
                                    }
                                }
                                .pickerStyle(.menu)

                                HStack {
                                    Button("Back") {
                                        withAnimation { profileStep = 2 }
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()

                                    Button("Continue") {
                                        withAnimation { step = 2 }
                                    }
                                    .buttonStyle(.borderedProminent)
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
        .onAppear { profileStep = 0 }
        .contentMargins(.bottom, bottomInset + 44, for: .scrollContent)
        .ignoresSafeArea(edges: .top)
    }

    private func routinePage(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                StretchableHeader(topSafeAreaInset: topInset) {
                    OnboardingMascotCover(style: .blaze)
                } content: {
                    VStack(spacing: 10) {
                        Text("Set up your day")
                            .font(.title.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)

                        Text("Choose your goal style, active hours, and reminder pace.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                VStack(spacing: 18) {
                    if routineStep == 0 {
                        onboardingCard(title: "Choose your daily goal") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Smart goal is easiest for most people. Turn on custom goal only if you already have a target.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

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

                                HStack {
                                    Button("Back") {
                                        withAnimation { step = 1 }
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()

                                    Button("Next") {
                                        withAnimation { routineStep = 1 }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    } else if routineStep == 1 {
                        onboardingCard(title: "When is your day usually active?") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("This helps us send reminders at better times.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                DatePicker("Wake", selection: $wakeTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                DatePicker("Sleep", selection: $sleepTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)

                                HStack {
                                    Button("Back") {
                                        withAnimation { routineStep = 0 }
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()

                                    Button("Next") {
                                        withAnimation { routineStep = 2 }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    } else {
                        onboardingCard(title: "How often should we remind you?") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Pick what feels right. You can always change this later.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Toggle("Enable reminders", isOn: $remindersEnabled)
                                    .onChange(of: remindersEnabled) { _, isEnabled in
                                        guard isEnabled else { return }
                                        Task { await notifier.requestAuthorization() }
                                    }

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

                                HStack {
                                    Button("Back") {
                                        withAnimation { routineStep = 1 }
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()

                                    Button("Continue") {
                                        withAnimation { step = 3 }
                                    }
                                    .buttonStyle(.borderedProminent)
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
        .onAppear { routineStep = 0 }
        .contentMargins(.bottom, bottomInset + 44, for: .scrollContent)
        .ignoresSafeArea(edges: .top)
    }

    private func permissionsPage(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                StretchableHeader(topSafeAreaInset: topInset) {
                    OnboardingMascotCover(style: .bolt)
                } content: {
                    VStack(spacing: 10) {
                        Text("Personalize your experience")
                            .font(.title.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)

                        Text("Choose optional smart features and meet your hydration buddy.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                VStack(spacing: 18) {
                    if permissionsStep == 2 {
                        onboardingCard(title: "Optional smart adjustments") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("These are optional. Turn them on only if you want more personalized goals.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Toggle(isOn: adaptiveWeatherBinding) {
                                    HStack {
                                        Label("Use local weather", systemImage: "cloud.sun.fill")
                                    }
                                }
                                .tint(Theme.mint)

                                Toggle(isOn: adaptiveWorkoutBinding) {
                                    HStack {
                                        Label("Use workout data", systemImage: "figure.run")
                                    }
                                }
                                .tint(Theme.mint)

                                HStack(spacing: 12) {
                                    Text(" Weather")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    if let legalURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                                        Link("Legal attribution", destination: legalURL)
                                            .font(.caption2)
                                    }
                                }

                                Button("Continue") {
                                    withAnimation { permissionsStep = 3 }
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    } else {
                        onboardingCard(title: "Pick your mascot") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose the buddy you want to see every day. You can change it later in Settings.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ZStack(alignment: .topTrailing) {
                                    premiumMascotSlide(style: onboardingMascotStyles[premiumMascotIndex], isFocused: true)
                                        .id(onboardingMascotStyles[premiumMascotIndex].id)
                                        .transition(
                                            .asymmetric(
                                                insertion: .move(edge: mascotSlideDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                                                removal: .move(edge: mascotSlideDirection > 0 ? .leading : .trailing).combined(with: .opacity)
                                            )
                                        )

                                    if isPreviewedMascotSelected {
                                        Label("Selected", systemImage: "checkmark.circle.fill")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(.thinMaterial, in: Capsule())
                                            .foregroundStyle(Theme.mint)
                                            .padding(10)
                                    }
                                }
                                .frame(height: 210)
                                .padding(.top, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(uiColor: .systemBackground).opacity(0.45))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(isPreviewedMascotSelected ? Theme.mint : Theme.glassBorder, lineWidth: isPreviewedMascotSelected ? 2 : 1)
                                )
                                .contentShape(Rectangle())
                                .animation(.easeInOut(duration: 0.35), value: premiumMascotIndex)
                                .gesture(
                                    DragGesture(minimumDistance: 20)
                                        .onEnded { value in
                                            if value.translation.width < -30 {
                                                advanceMascot(by: 1)
                                            } else if value.translation.width > 30 {
                                                advanceMascot(by: -1)
                                            }
                                        }
                                )

                                HStack(spacing: 10) {
                                    Button {
                                        advanceMascot(by: -1)
                                    } label: {
                                        Image(systemName: "chevron.left")
                                    }
                                    .buttonStyle(.bordered)

                                    ForEach(onboardingMascotStyles.indices, id: \.self) { index in
                                        Circle()
                                            .fill(index == premiumMascotIndex ? Theme.lagoon : .secondary.opacity(0.35))
                                            .frame(width: index == premiumMascotIndex ? 8 : 6, height: index == premiumMascotIndex ? 8 : 6)
                                    }

                                    Button {
                                        advanceMascot(by: 1)
                                    } label: {
                                        Image(systemName: "chevron.right")
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .frame(maxWidth: .infinity)

                                HStack {
                                    Button("Back") {
                                        withAnimation { permissionsStep = 2 }
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()

                                    Button("Get Started") {
                                        Haptics.success()
                                        showEndOfOnboardingPaywall = true
                                    }
                                    .buttonStyle(.borderedProminent)
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
        .onAppear {
            permissionsStep = 2
            selectedMascotStyle = MascotStyle.from(id: selectedMascotID)
            if let index = onboardingMascotStyles.firstIndex(of: selectedMascotStyle) {
                premiumMascotIndex = index
            } else {
                premiumMascotIndex = 0
            }
            Task {
                await notifier.refreshAuthorizationStatus()
                await healthKit.refreshAuthorizationStatus()
            }
        }
        .contentMargins(.bottom, bottomInset + 44, for: .scrollContent)
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
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.14), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
        .shadow(color: Theme.lagoon.opacity(0.08), radius: 14, x: 0, y: 8)
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

    private func premiumMascotSlide(style: MascotStyle, isFocused: Bool) -> some View {
        VStack(spacing: 10) {
            MascotView(size: isFocused ? 96 : 80, animated: true, style: style)

            Text(style.name)
                .font(.subheadline.weight(.semibold))

            Text(style.tagline)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 6)
        .scaleEffect(isFocused ? 1 : 0.92)
        .opacity(isFocused ? 1 : 0.7)
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

    private var locationPermissionEnabled: Bool {
        locationManager.authorizationStatus == .authorizedAlways ||
        locationManager.authorizationStatus == .authorizedWhenInUse
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

    private var isPreviewedMascotSelected: Bool {
        onboardingMascotStyles[premiumMascotIndex] == selectedMascotStyle
    }

    private func advanceMascot(by direction: Int) {
        guard !onboardingMascotStyles.isEmpty else { return }
        mascotSlideDirection = direction >= 0 ? 1 : -1

        withAnimation(.easeInOut(duration: 0.35)) {
            let next = premiumMascotIndex + direction
            premiumMascotIndex = (next % onboardingMascotStyles.count + onboardingMascotStyles.count) % onboardingMascotStyles.count
            selectedMascotStyle = onboardingMascotStyles[premiumMascotIndex]
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func finishOnboarding() {
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightKg = unitSystem.kg(from: weight)
        let customGoalML = customGoalEnabled ? unitSystem.ml(from: customGoalValue) : nil

        selectedMascotID = selectedMascotStyle.rawValue

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
            profile.prefersWeatherGoal = prefersWeather && locationPermissionEnabled
            profile.prefersHealthKit = prefersHealthKit && healthKit.isAuthorized
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

/// A stretchable header that expands when pulled down and shrinks when scrolled up
private struct StretchableHeader<Content: View, Background: View>: View {
    let topSafeAreaInset: CGFloat
    @ViewBuilder let background: Background
    @ViewBuilder let content: Content
    
    private let baseHeight: CGFloat = UIScreen.main.bounds.height * 0.5
    
    private var totalHeight: CGFloat {
        baseHeight + topSafeAreaInset
    }
    
    var body: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let isStretching = minY > 0
            let stretchAmount = isStretching ? minY : 0
            let imageHeight = totalHeight + stretchAmount
            
            ZStack(alignment: .bottom) {
                // Background view - fills entire area including safe area
                background
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(width: geometry.size.width, height: imageHeight)
                    .clipped()
                
                // Dark overlay gradient for text readability
                LinearGradient(
                    colors: [
                        .clear,
                        .clear,
                        .black.opacity(0.4),
                        .black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geometry.size.width, height: imageHeight)
                
                // Content overlay
                content
                    .frame(maxWidth: .infinity, alignment: .bottom)
            }
            .frame(width: geometry.size.width, height: imageHeight, alignment: .bottom)
            .clipped()
            .offset(y: isStretching ? -stretchAmount : 0)
        }
        .frame(height: totalHeight)
        .ignoresSafeArea(edges: .top)
    }
}

private struct OnboardingMascotCover: View {
    let style: MascotStyle

    @State private var float = false
    @State private var rotateGlow = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    (style.colors.first ?? Theme.lagoon).opacity(0.75),
                    (style.colors.last ?? Theme.mint).opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .offset(x: -100, y: -60)
                .scaleEffect(float ? 1.08 : 0.96)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 160, height: 160)
                .offset(x: 120, y: -40)
                .scaleEffect(float ? 0.95 : 1.06)

            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(rotateGlow ? 360 : 0))

            MascotView(size: 150, animated: true, style: style)
                .shadow(color: Theme.lagoon.opacity(0.3), radius: 18, x: 0, y: 12)
                .offset(y: float ? 32 : 46)
                .rotation3DEffect(.degrees(float ? 0 : 4), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                float = true
            }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                rotateGlow = true
            }
        }
    }
}

#if DEBUG
#Preview("Onboarding") {
    PreviewEnvironment {
        OnboardingView { }
    }
}
#endif
