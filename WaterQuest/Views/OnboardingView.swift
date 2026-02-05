import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var locationManager: LocationManager

    var onComplete: () -> Void

    @State private var pageIndex = 0
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

    private let remindersNotificationsIndex = 4
    private let weatherLocationIndex = 5
    private let healthActivityIndex = 6
    private let lastPageIndex = 7
    
    // Animation states
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .top) {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                TabView(selection: $pageIndex) {
                    introPage.tag(0)
                    profilePage.tag(1)
                    schedulePage.tag(2)
                    customGoalPage.tag(3)
                    remindersNotificationsPage.tag(4)
                    weatherLocationPage.tag(5)
                    healthActivityPage.tag(6)
                    trialPage.tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: pageIndex) { oldValue, newValue in
                    Haptics.impact(.light)
                    Task { await requestPermissionsIfNeeded(for: oldValue, movingTo: newValue) }
                }

                // Navigation buttons
                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2)) {
                appeared = true
            }
        }
    }
    
    // MARK: - Navigation Buttons
    @ViewBuilder
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if pageIndex > 0 {
                Button {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        pageIndex -= 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(Theme.bodyFont(size: 16))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .modifier(GlassButtonModifier())
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }

            Button {
                if pageIndex == lastPageIndex {
                    Haptics.success()
                    finishOnboarding()
                } else {
                    Haptics.impact(.medium)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        pageIndex += 1
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(pageIndex == lastPageIndex ? "Start Quest" : "Next")
                        .font(Theme.titleFont(size: 16))
                    if pageIndex < lastPageIndex {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            }
            .modifier(GlassButtonModifier(tint: Theme.lagoon))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: pageIndex)
    }

    // MARK: - Intro Page
    private var introPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Enhanced mascot with glass backdrop
            ZStack {
                // Glass backdrop circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 160, height: 160)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Theme.lagoon.opacity(0.3), radius: 30, x: 0, y: 10)
                
                EnhancedMascotView()
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
            
            VStack(spacing: 12) {
                Text("WaterQuest")
                    .font(Theme.titleFont(size: 38))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Theme.mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Theme.lagoon.opacity(0.5), radius: 10, x: 0, y: 4)
                
                Text("A gentle hydration companion that builds steady energy, focus, and recovery through small daily wins.")
                    .font(Theme.bodyFont(size: 17))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .offset(y: appeared ? 0 : 30)
            .opacity(appeared ? 1 : 0)
            
            // Feature pills
            HStack(spacing: 12) {
                FeaturePill(icon: "calendar.badge.checkmark", text: "Consistency", color: Theme.coral)
                FeaturePill(icon: "drop.circle", text: "Daily Flow", color: Theme.lagoon)
                FeaturePill(icon: "sunrise.fill", text: "Steady Energy", color: Theme.mint)
            }
            .padding(.top, 8)
            .offset(y: appeared ? 0 : 40)
            .opacity(appeared ? 1 : 0)
            
            Spacer()
            Spacer()
        }
        .padding(.top, 20)
        .modifier(OnboardingPageTransition())
    }

    // MARK: - Trial Page
    private var trialPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeader(
                    icon: "gift.fill",
                    title: "Your Free Trial",
                    subtitle: "Experience calm, guided hydration from day one"
                )

                DropletChatStack(messages: [
                    "Welcome to your calm start. We will guide hydration gently, not aggressively.",
                    "During your trial, you get premium quests, deeper insights, and quiet automation.",
                    "Over time, this becomes a steady rhythm that supports energy, focus, and recovery."
                ])
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .modifier(OnboardingPageTransition())
    }

    // MARK: - Profile Page
    private var profilePage: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeader(
                    icon: "person.crop.circle.fill",
                    title: "Build Your Profile",
                    subtitle: "Personalize goals so hydration feels natural and sustainable"
                )

                VStack(spacing: 16) {
                    DropletChatStack(messages: [
                        "Tell me a little about you so your plan feels personal and sustainable.",
                        "Your units, weight, and activity level help me shape a calm, realistic goal."
                    ])

                    GlassTextField(
                        title: "What should we call you?",
                        placeholder: "Your name",
                        text: $name
                    )

                    GlassSegmentedPicker(
                        title: "Preferred Units",
                        selection: $unitSystem,
                        options: UnitSystem.allCases
                    ) { unit in
                        Text(unit == .metric ? "Metric" : "Imperial")
                    }

                    GlassSlider(
                        title: "Your Weight",
                        value: $weight,
                        range: unitSystem == .metric ? 40...140 : 90...300,
                        step: unitSystem == .metric ? 1 : 2,
                        unit: unitSystem.bodyWeightUnit
                    )

                    GlassSegmentedPicker(
                        title: "Activity Level",
                        selection: $activityLevel,
                        options: ActivityLevel.allCases
                    ) { level in
                        Text(level.label)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .modifier(OnboardingPageTransition())
    }

    // MARK: - Schedule Page
    private var schedulePage: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeader(
                    icon: "clock.fill",
                    title: "Daily Rhythm",
                    subtitle: "Shape a rhythm that feels effortless"
                )

                VStack(spacing: 16) {
                    DropletChatStack(messages: [
                        "When do your days begin and end?",
                        "I will pace goals and reminders so hydration feels calm and unhurried."
                    ])

                    HStack(spacing: 12) {
                        GlassTimePicker(title: "Wake Up", icon: "sunrise.fill", date: $wakeTime, tint: Theme.sun)
                        GlassTimePicker(title: "Sleep", icon: "moon.stars.fill", date: $sleepTime, tint: Theme.lagoon)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .modifier(OnboardingPageTransition())
    }

    // MARK: - Custom Goal Page
    private var customGoalPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeader(
                    icon: "target",
                    title: "Custom Daily Goal",
                    subtitle: "Honor the target that feels right for you"
                )

                VStack(spacing: 16) {
                    DropletChatStack(messages: [
                        "If you already have a target from a clinician or coach, we can honor it.",
                        "That keeps your quests and progress aligned with what matters most to you."
                    ])

                    GlassToggle(
                        title: "Custom Daily Goal",
                        subtitle: "Use a personal target",
                        isOn: $customGoalEnabled,
                        tint: Theme.mint
                    )

                    if customGoalEnabled {
                        GlassSlider(
                            title: "Daily Goal",
                            value: $customGoalValue,
                            range: unitSystem == .metric ? 1500...4500 : 50...150,
                            step: unitSystem == .metric ? 50 : 2,
                            unit: unitSystem.volumeUnit
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: customGoalEnabled)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .modifier(OnboardingPageTransition())
    }

    // MARK: - Reminders + Notifications
    private var remindersNotificationsPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeader(
                    icon: "bell.badge.fill",
                    title: "Reminders & Notifications",
                    subtitle: "Supportive nudges that feel easy"
                )

                VStack(spacing: 16) {
                    DropletChatStack(messages: [
                        "I can offer gentle reminders so hydration feels automatic.",
                        "We will space them across your day, keeping your rhythm steady.",
                        "If you allow notifications, I can support you even on busy days."
                    ])

                    GlassToggle(
                        title: "Smart Reminders",
                        subtitle: "Receive gentle reminders",
                        isOn: $remindersEnabled,
                        tint: Theme.lagoon
                    )

                    if remindersEnabled {
                        GlassStepper(
                            title: "Reminders per Day",
                            value: $reminderCount,
                            range: 3...12
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                        ))
                    }

                    PermissionButton(
                        title: "Notifications",
                        icon: "bell.fill",
                        color: Theme.coral
                    ) {
                        Haptics.impact(.medium)
                        Task { await notifier.requestAuthorization() }
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: remindersEnabled)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .modifier(OnboardingPageTransition())
    }

    // MARK: - Weather + Location
    private var weatherLocationPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeader(
                    icon: "cloud.sun.fill",
                    title: "Weather & Location",
                    subtitle: "Match hydration to your day"
                )

                VStack(spacing: 16) {
                    DropletChatStack(messages: [
                        "Weather changes your needs more than you think.",
                        "If you enable weather, I can keep goals calm and balanced.",
                        "Location gives me accurate local conditions, no guesswork."
                    ])

                    GlassToggle(
                        title: "Weather Integration",
                        subtitle: "Adjust goals with weather",
                        isOn: $prefersWeather,
                        tint: Theme.sun
                    )

                    PermissionButton(
                        title: "Location",
                        icon: "location.fill",
                        color: Theme.lagoon
                    ) {
                        Haptics.impact(.medium)
                        locationManager.requestPermission()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .modifier(OnboardingPageTransition())
    }

    // MARK: - Health + Activity
    private var healthActivityPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeader(
                    icon: "heart.fill",
                    title: "Health & Activity",
                    subtitle: "Align hydration with movement"
                )

                VStack(spacing: 16) {
                    DropletChatStack(messages: [
                        "Movement changes what your body needs, even on ordinary days.",
                        "If you enable Health, I can lift goals gently to support recovery.",
                        "Workout and energy data help me estimate your extra hydration."
                    ])

                    GlassToggle(
                        title: "Health Sync",
                        subtitle: "Connect activity and water intake",
                        isOn: $prefersHealthKit,
                        tint: Theme.mint
                    )

                    PermissionButton(
                        title: "Health & Activity",
                        icon: "heart.fill",
                        color: .pink
                    ) {
                        Haptics.impact(.medium)
                        Task { await healthKit.requestAuthorization() }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .modifier(OnboardingPageTransition())
    }

    // MARK: - Helpers
    private func requestPermissionsIfNeeded(for previousIndex: Int, movingTo newIndex: Int) async {
        guard newIndex > previousIndex else { return }

        switch previousIndex {
        case remindersNotificationsIndex:
            guard remindersEnabled else { return }
            await notifier.refreshAuthorizationStatus()
            if notifier.authorizationStatus != .authorized {
                await notifier.requestAuthorization()
            }
        case weatherLocationIndex:
            guard prefersWeather else { return }
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            }
        case healthActivityIndex:
            guard prefersHealthKit else { return }
            await healthKit.refreshAuthorizationStatus()
            if healthKit.isAvailable && !healthKit.isAuthorized {
                await healthKit.requestAuthorization()
            }
        default:
            break
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
            notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            onComplete()
        }
    }

    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

// MARK: - Glass Background Modifier (iOS 26+ Liquid Glass, fallback for older)
struct GlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tint: Color? = nil
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    tint.map { .regular.tint($0) } ?? .regular,
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Glass Button Modifier
struct GlassButtonModifier: ViewModifier {
    var tint: Color? = nil
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    tint.map { .regular.tint($0).interactive() } ?? .regular.interactive(),
                    in: .capsule
                )
        } else {
            content
                .background(
                    Capsule()
                        .fill(tint?.opacity(0.3) ?? Color.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: (tint ?? Theme.lagoon).opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Glass Circle Modifier
struct GlassCircleModifier: ViewModifier {
    var tint: Color? = nil
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    tint.map { .regular.tint($0).interactive() } ?? .regular.interactive(),
                    in: .circle
                )
        } else {
            content
                .background(
                    Circle()
                        .fill(tint?.opacity(0.3) ?? Color.white.opacity(0.15))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Animated Gradient Background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.deepSea, Theme.night],
                startPoint: animateGradient ? .topLeading : .top,
                endPoint: animateGradient ? .bottomTrailing : .bottom
            )
            
            // Floating orbs
            Circle()
                .fill(Theme.lagoon.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animateGradient ? 100 : -100, y: animateGradient ? -150 : -100)
            
            Circle()
                .fill(Theme.mint.opacity(0.1))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: animateGradient ? -80 : 80, y: animateGradient ? 200 : 150)
            
            Circle()
                .fill(Theme.coral.opacity(0.08))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: animateGradient ? 50 : -50, y: animateGradient ? 50 : 100)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

// MARK: - Page Header
struct PageHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.lagoon, Theme.mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Theme.lagoon.opacity(0.4), radius: 8, x: 0, y: 4)
            
            Text(title)
                .font(Theme.titleFont(size: 28))
                .foregroundColor(Theme.textPrimary)
            
            Text(subtitle)
                .font(Theme.bodyFont(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Feature Pill
struct FeaturePill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(Theme.bodyFont(size: 13))
        }
        .foregroundColor(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .modifier(GlassButtonModifier(tint: color))
    }
}

// MARK: - Droplet Chat Stack
struct DropletChatStack: View {
    let messages: [String]

    @State private var revealedIndex: Int = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(messages.indices, id: \.self) { index in
                ChatBubble(text: messages[index])
                    .opacity(revealedIndex >= index ? 1 : 0)
                    .offset(y: revealedIndex >= index ? 0 : 16)
            }
        }
        .onAppear {
            revealedIndex = -1
            for index in messages.indices {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(Double(index) * 0.12)) {
                    revealedIndex = index
                }
            }
        }
    }
}

struct ChatBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.lagoon.opacity(0.2))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .stroke(Theme.glassBorder.opacity(0.5), lineWidth: 1)
                    )
                Image(systemName: "drop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.lagoon, Theme.mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(text)
                .font(Theme.bodyFont(size: 15))
                .foregroundColor(Theme.textPrimary)
                .lineSpacing(4)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Theme.glassBorder.opacity(0.4), lineWidth: 1)
                        )
                )

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Onboarding Page Transition
struct OnboardingPageTransition: ViewModifier {
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 24)
            .scaleEffect(isVisible ? 1 : 0.98)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    isVisible = true
                }
            }
            .onDisappear {
                isVisible = false
            }
    }
}

// MARK: - Enhanced Mascot View
struct EnhancedMascotView: View {
    @State private var bounce = false
    
    var body: some View {
        ZStack {
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.lagoon, Theme.mint, Theme.lagoon],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Theme.lagoon.opacity(0.5), radius: 16, x: 0, y: 8)

            // Face
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Eye()
                    Eye()
                }
                
                // Smile
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 20, height: 6)
            }
            .offset(y: 10)
        }
        .frame(width: 90, height: 110)
        .scaleEffect(bounce ? 1.06 : 1.0)
        .offset(y: bounce ? -4 : 0)
        .rotation3DEffect(.degrees(bounce ? 2 : -2), axis: (x: 0, y: 1, z: 0))
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: bounce)
        .onAppear {
            bounce = true
        }
    }
}

struct Eye: View {
    @State private var blink = false
    
    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.7))
            .frame(width: 8, height: blink ? 2 : 8)
            .animation(.easeInOut(duration: 0.1), value: blink)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                    blink = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        blink = false
                    }
                }
            }
    }
}

// MARK: - Glass Components
struct GlassTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(Theme.textSecondary)
            
            TextField(placeholder, text: $text)
                .font(Theme.bodyFont(size: 17))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.glassBorder.opacity(0.4), lineWidth: 1)
                        )
                )
        }
    }
}

struct GlassSegmentedPicker<T: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    @ViewBuilder let content: (T) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(Theme.textSecondary)
            
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    content(option).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selection) {
                Haptics.selection()
            }
        }
    }
}

struct GlassSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Text("\(Int(value)) \(unit)")
                    .font(Theme.titleFont(size: 18))
                    .foregroundColor(Theme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
            }
            
            Slider(value: $value, in: range, step: step) { editing in
                if !editing {
                    Haptics.selection()
                }
            }
            .tint(Theme.lagoon)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.glassBorder.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct GlassToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let tint: Color
    
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(Theme.textPrimary)
                
                Text(subtitle)
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: tint))
                .labelsHidden()
                .onChange(of: isOn) {
                    Haptics.selection()
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.glassBorder.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct GlassTimePicker: View {
    let title: String
    let icon: String
    @Binding var date: Date
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(tint)
                Text(title)
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
            
            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(tint)
                .onChange(of: date) {
                    Haptics.selection()
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.glassBorder.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct GlassStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        HStack {
            Text(title)
                .font(Theme.bodyFont(size: 16))
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    if value > range.lowerBound {
                        value -= 1
                        Haptics.impact(.light)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 32, height: 32)
                }
                .modifier(GlassCircleModifier())
                .opacity(value > range.lowerBound ? 1 : 0.4)
                
                Text("\(value)")
                    .font(Theme.titleFont(size: 20))
                    .foregroundColor(Theme.textPrimary)
                    .frame(minWidth: 30)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
                
                Button {
                    if value < range.upperBound {
                        value += 1
                        Haptics.impact(.light)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 32, height: 32)
                }
                .modifier(GlassCircleModifier())
                .opacity(value < range.upperBound ? 1 : 0.4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.glassBorder.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct PermissionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .modifier(GlassCircleModifier(tint: color.opacity(0.5)))
                
                Text("Enable \(title)")
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Theme.glassBorder.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview("Onboarding") {
    PreviewEnvironment {
        OnboardingView { }
    }
}
