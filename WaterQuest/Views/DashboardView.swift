import SwiftUI
import CoreMotion

struct DashboardView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var weather: WeatherClient
    @EnvironmentObject private var healthKit: HealthKitManager

    @StateObject private var aiService = HydrationAIService()
    @Namespace private var glassNamespace

    @State private var isRefreshing = false
    @State private var showContent = false
    @State private var progressScale: CGFloat = 0.8
    @State private var headerOffset: CGFloat = -30
    @State private var cardsOpacity: Double = 0
    @State private var rippleTrigger = false
    @State private var tiltOffset: CGSize = .zero
    @State private var motionManager = CMMotionManager()

    var body: some View {
        ZStack(alignment: .top) {
            // Animated background
            animatedBackground

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                        .offset(y: headerOffset)
                        .opacity(showContent ? 1 : 0)

                    progressCard
                        .scaleEffect(progressScale)
                        .opacity(showContent ? 1 : 0)

                    aiTipCard
                        .opacity(cardsOpacity)

                    quickAdd
                        .opacity(cardsOpacity)

                    statsGrid
                        .opacity(cardsOpacity)

                    questsSection
                        .opacity(cardsOpacity)

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .modifier(ScrollEdgeEffectModifier())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            await refreshSignals()
            await generateAITip()
        }
        .onAppear {
            animateEntrance()
            startMotionUpdates()
        }
        .onDisappear {
            stopMotionUpdates()
        }
        .animation(Theme.fluidSpring, value: store.gameState.quests)
        .modifier(SensoryFeedbackModifier(trigger: rippleTrigger))
    }

    // MARK: - Animated Background
    private var animatedBackground: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // Subtle animated gradient overlay
            GeometryReader { geometry in
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        let colors: [Color] = [
                            Theme.lagoon.opacity(0.15),
                            Theme.mint.opacity(0.1),
                            Theme.deepSea.opacity(0.2)
                        ]

                        for i in 0..<3 {
                            let phase = time * 0.3 + Double(i) * 2
                            let yOffset = sin(phase) * 50
                            let path = Path(ellipseIn: CGRect(
                                x: size.width * CGFloat(i) * 0.3 - 100,
                                y: size.height * 0.3 + yOffset,
                                width: size.width * 0.8,
                                height: size.height * 0.5
                            ))
                            context.fill(path, with: .color(colors[i]))
                        }
                    }
                    .blur(radius: 80)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(Theme.titleFont(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.sun)

                    Text("Level \(store.gameState.level)")
                        .font(Theme.bodyFont(size: 14))
                        .foregroundColor(.white.opacity(0.8))

                    Text("•")
                        .foregroundColor(.white.opacity(0.4))

                    Text("\(store.gameState.xp) XP")
                        .font(Theme.bodyFont(size: 14))
                        .foregroundColor(Theme.mint)
                }
            }

            Spacer()

            MascotView()
                .scaleEffect(0.9)
        }
        .padding(.vertical, 8)
    }

    private var greeting: String {
        if store.profile.name.isEmpty {
            return "Hydration Quest"
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        case 17..<21: timeGreeting = "Good evening"
        default: timeGreeting = "Hello"
        }
        return "\(timeGreeting), \(store.profile.name)"
    }

    // MARK: - Progress Card
    private var progressCard: some View {
        let goal = store.dailyGoal
        let progress = min(1, store.todayTotalML / max(1, goal.totalML))

        return ProgressCardContent(
            progress: progress,
            todayTotalML: store.todayTotalML,
            goalTotalML: goal.totalML,
            unitSystem: store.profile.unitSystem,
            streakDays: store.gameState.streakDays,
            coins: store.gameState.coins,
            tiltOffset: tiltOffset
        )
    }

    // MARK: - AI Tip Card
    @ViewBuilder
    private var aiTipCard: some View {
        if let tip = aiService.currentTip {
            LiquidGlassCard(cornerRadius: 20, tintColor: tip.category.color.opacity(0.3), isInteractive: true) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(tip.category.color.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: tip.category.icon)
                            .font(.system(size: 20))
                            .foregroundColor(tip.category.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if aiService.isAvailable {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.glassAccent)
                            }
                            Text("Droplet says")
                                .font(Theme.bodyFont(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Text(tip.message)
                            .font(Theme.bodyFont(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if aiService.isGenerating {
                        ProgressView()
                            .tint(Theme.mint)
                            .scaleEffect(0.8)
                    }
                }
                .padding(16)
            }
            .onTapGesture {
                Task {
                    Haptics.selection()
                    await generateAITip()
                }
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    // MARK: - Quick Add Section
    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Add")
                .font(Theme.titleFont(size: 18))
                .foregroundColor(.white)

            let unit = store.profile.unitSystem
            let buttons = unit == .metric ? [200, 350, 500, 750] : [8, 12, 16, 24]

            HStack(spacing: 10) {
                ForEach(buttons, id: \.self) { amount in
                    QuickAddPill(amount: amount, unit: unit.volumeUnit) {
                        withAnimation(Theme.fluidSpring) {
                            store.addIntake(amount: Double(amount), source: .manual)
                            rippleTrigger.toggle()
                        }
                        Task {
                            try? await Task.sleep(for: .milliseconds(500))
                            await generateAITip()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's Context")
                .font(Theme.titleFont(size: 18))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                FluidStatCard(
                    label: "Weather",
                    value: weatherText,
                    icon: weatherIcon,
                    accentColor: Theme.lagoon
                )

                FluidStatCard(
                    label: "Activity",
                    value: "\(Int(store.lastWorkout.exerciseMinutes)) min",
                    icon: "figure.run",
                    accentColor: Theme.coral
                )
            }
        }
    }

    private var weatherText: String {
        guard let snapshot = store.activeWeather else { return "--" }
        let temp = "\(Int(snapshot.temperatureC))°C"
        if snapshot.condition.isEmpty { return temp }
        return "\(temp) · \(snapshot.condition)"
    }

    private var weatherIcon: String {
        guard let key = store.activeWeather?.conditionKey, !key.isEmpty else {
            // Fallback for legacy snapshots with no conditionKey
            guard let temp = store.activeWeather?.temperatureC else { return "cloud.fill" }
            if temp > 30 { return "sun.max.fill" }
            if temp > 20 { return "sun.min.fill" }
            if temp > 10 { return "cloud.sun.fill" }
            return "cloud.fill"
        }
        return WeatherSnapshot.sfSymbol(for: key)
    }

    // MARK: - Quests Section
    private var questsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily Quests")
                    .font(Theme.titleFont(size: 18))
                    .foregroundColor(.white)

                Spacer()

                if isRefreshing {
                    ProgressView()
                        .tint(Theme.mint)
                        .scaleEffect(0.8)
                }
            }

            ForEach(Array(store.gameState.quests.enumerated()), id: \.element.id) { index, quest in
                let progress = min(1, quest.progressML / max(1, quest.targetML))
                QuestCard(quest: quest, progress: progress)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
    }

    // MARK: - Actions
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let roll = motion.attitude.roll
            let pitch = motion.attitude.pitch
            let xOffset = CGFloat(roll) * 12
            let yOffset = CGFloat(-pitch) * 10
            tiltOffset = CGSize(width: xOffset, height: yOffset)
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        tiltOffset = .zero
    }

    private func animateEntrance() {
        withAnimation(Theme.fluidSpring.delay(0.1)) {
            showContent = true
            headerOffset = 0
        }

        withAnimation(Theme.fluidSpring.delay(0.2)) {
            progressScale = 1.0
        }

        withAnimation(Theme.gentleSpring.delay(0.4)) {
            cardsOpacity = 1.0
        }
    }

    private func refreshSignals() async {
        isRefreshing = true

        if store.profile.prefersHealthKit {
            let summary = await healthKit.fetchTodayWorkoutSummary()
            await MainActor.run {
                store.updateWorkout(summary)
            }
        }

        if store.profile.prefersWeatherGoal {
            await weather.refresh()
            if let snapshot = weather.currentWeather {
                await MainActor.run {
                    store.updateWeather(snapshot)
                }
            }
        }

        await MainActor.run {
            store.refreshQuests()
            isRefreshing = false
        }
    }

    private func generateAITip() async {
        await aiService.generateTip(
            currentIntake: store.todayTotalML,
            goalML: store.dailyGoal.totalML,
            streakDays: store.gameState.streakDays,
            weatherTemp: store.activeWeather?.temperatureC,
            exerciseMinutes: Int(store.lastWorkout.exerciseMinutes),
            timeOfDay: TimeOfDay.current
        )
    }
}

// MARK: - Progress Card Content (with iOS 26 Glass Effect support)
struct ProgressCardContent: View {
    let progress: Double
    let todayTotalML: Double
    let goalTotalML: Double
    let unitSystem: UnitSystem
    let streakDays: Int
    let coins: Int
    let tiltOffset: CGSize

    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26ProgressCard(
                progress: progress,
                todayTotalML: todayTotalML,
                goalTotalML: goalTotalML,
                unitSystem: unitSystem,
                streakDays: streakDays,
                coins: coins,
                tiltOffset: tiltOffset
            )
        } else {
            legacyProgressCard
        }
    }

    private var legacyProgressCard: some View {
        LiquidGlassCard(cornerRadius: 28, tintColor: Theme.lagoon.opacity(0.1)) {
            VStack(spacing: 20) {
                // Progress (single, clear indicator)
                VStack(alignment: .leading, spacing: 14) {

                    LiquidFillGauge(
                        progress: progress,
                        tiltOffset: tiltOffset,
                        todayTotalML: todayTotalML,
                        goalTotalML: goalTotalML,
                        unitSystem: unitSystem
                    )
                    .frame(height: 220)
                }

                // Stats Row
                HStack(spacing: 16) {
                    miniStatPill(
                        icon: "flame.fill",
                        label: "Streak",
                        value: "\(streakDays)",
                        unit: "days",
                        color: Theme.coral
                    )

                    miniStatPill(
                        icon: "bitcoinsign.circle.fill",
                        label: "Coins",
                        value: "\(coins)",
                        unit: "",
                        color: Theme.sun
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .shadow(color: Theme.lagoon.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    private func miniStatPill(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.bodyFont(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 4) {
                    Text(value)
                        .font(Theme.titleFont(size: 18))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())

                    if !unit.isEmpty {
                        Text(unit)
                            .font(Theme.bodyFont(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(Theme.liquidGlassGradient)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Theme.glassBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - iOS 26 Progress Card with Native Glass Effects
@available(iOS 26.0, *)
struct iOS26ProgressCard: View {
    let progress: Double
    let todayTotalML: Double
    let goalTotalML: Double
    let unitSystem: UnitSystem
    let streakDays: Int
    let coins: Int
    let tiltOffset: CGSize

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    LiquidFillGauge(
                        progress: progress,
                        tiltOffset: tiltOffset,
                        todayTotalML: todayTotalML,
                        goalTotalML: goalTotalML,
                        unitSystem: unitSystem
                    )
                    .frame(height: 220)
                }

                HStack(spacing: 16) {
                    miniStatPillGlass(icon: "flame.fill", label: "Streak", value: "\(streakDays)", unit: "days", color: Theme.coral)
                    miniStatPillGlass(icon: "bitcoinsign.circle.fill", label: "Coins", value: "\(coins)", unit: "", color: Theme.sun)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.tint(Theme.lagoon.opacity(0.1)), in: .rect(cornerRadius: 28))
        }
        .shadow(color: Theme.lagoon.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    private func miniStatPillGlass(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.bodyFont(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 4) {
                    Text(value)
                        .font(Theme.titleFont(size: 18))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())

                    if !unit.isEmpty {
                        Text(unit)
                            .font(Theme.bodyFont(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: - Liquid Fill Gauge
struct LiquidFillGauge: View {
    let progress: Double
    let tiltOffset: CGSize
    let todayTotalML: Double
    let goalTotalML: Double
    let unitSystem: UnitSystem

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let diameter = min(size.width, size.height)
            let ringWidth = diameter * 0.14
            let innerDiameter = diameter - ringWidth * 2
            let clampedProgress = min(1, max(0, progress))
            let fillHeight = diameter * clampedProgress
            let liquidTop = diameter - fillHeight
            let ringInset = ringWidth

            ZStack {
                if #available(iOS 19.0, *) {
                    Circle()
                        .glassEffect(.regular.tint(Theme.lagoon.opacity(0.08)).interactive(), in: .circle)
                        .frame(width: diameter, height: diameter)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: diameter, height: diameter)
                }

                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase1 = CGFloat(time * 1.2)
                    let phase2 = CGFloat(time * 1.6)

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.mint.opacity(0.6), Theme.lagoon.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: diameter, height: diameter)

                        WaveShape(phase: phase1, strength: 5)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.mint.opacity(0.8), Theme.lagoon.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: diameter, height: 26)
                            .offset(
                                x: tiltOffset.width * 0.6,
                                y: liquidTop - 8 + tiltOffset.height * 0.35
                            )

                        WaveShape(phase: phase2, strength: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.mint.opacity(0.5), Theme.lagoon.opacity(0.75)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: diameter, height: 22)
                            .offset(
                                x: -tiltOffset.width * 0.45,
                                y: liquidTop - 4 + tiltOffset.height * 0.25
                            )
                    }
                    .mask(
                        Rectangle()
                            .frame(width: diameter, height: fillHeight)
                            .offset(y: liquidTop)
                    )
                    .mask(Circle().frame(width: diameter, height: diameter))
                }
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        .frame(width: diameter, height: diameter)
                )
                .mask(
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: ringWidth))
                        .frame(width: diameter, height: diameter)
                )

                Circle()
                    .fill(Color.clear)
                    .frame(width: innerDiameter, height: innerDiameter)

                VStack(spacing: 6) {
                    Text(Formatters.percentString(progress))
                        .font(Theme.titleFont(size: 30))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())

                    Text("\(Formatters.volumeString(ml: todayTotalML, unit: unitSystem))")
                        .font(Theme.bodyFont(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                        .contentTransition(.numericText())

                    Text("of \(Formatters.volumeString(ml: goalTotalML, unit: unitSystem))")
                        .font(Theme.bodyFont(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: innerDiameter * 0.9)
                .padding(.top, ringInset * 0.1)
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

// MARK: - Availability Modifiers
struct ScrollEdgeEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

struct SensoryFeedbackModifier: ViewModifier {
    let trigger: Bool

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.sensoryFeedback(.selection, trigger: trigger)
        } else {
            content
        }
    }
}

// MARK: - Preview
#Preview("Dashboard") {
    PreviewEnvironment {
        DashboardView()
    }
}
