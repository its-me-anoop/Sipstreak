import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @AppStorage("appTheme") private var appThemeRawValue: Int = AppTheme.system.rawValue
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = true
    @AppStorage("hasOnboardedLocally") private var hasOnboardedLocally: Bool = true

    @State private var customGoalEnabled = false
    @State private var customGoalValue: Double = 2200
    @State private var wakeTime: Date = Date()
    @State private var sleepTime: Date = Date()
    @State private var showPaywall = false
    @State private var showResetTodayAlert = false
    @State private var showClearAllDataAlert = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showResetOnboardingAlert = false
    @State private var pendingEnableWeatherAdjustment = false
    @State private var pendingEnableWorkoutAdjustment = false

    var body: some View {
        Form {
            profileSection
            appearanceSection
            subscriptionSection
            goalSection
            scheduleSection
            reminderSection
            permissionsSection
            dataManagementSection
            aboutSection
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
        .task {
            await notifier.refreshAuthorizationStatus()
            await healthKit.refreshAuthorizationStatus()
            await subscriptionManager.refreshStatus()
        }
        .onAppear {
            hydrateLocalStateFromProfile()
            syncAdaptiveSettingsWithPermissions()
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            let enabled = status == .authorizedAlways || status == .authorizedWhenInUse
            if enabled {
                if pendingEnableWeatherAdjustment {
                    store.updateProfile { $0.prefersWeatherGoal = true }
                }
                pendingEnableWeatherAdjustment = false
            } else {
                if status == .denied || status == .restricted {
                    pendingEnableWeatherAdjustment = false
                }
                if store.profile.prefersWeatherGoal {
                    store.updateProfile { $0.prefersWeatherGoal = false }
                }
            }
        }
        .onChange(of: healthKit.isAuthorized) { _, isAuthorized in
            if isAuthorized {
                if pendingEnableWorkoutAdjustment {
                    store.updateProfile { $0.prefersHealthKit = true }
                }
                pendingEnableWorkoutAdjustment = false
            } else {
                pendingEnableWorkoutAdjustment = false
                if store.profile.prefersHealthKit {
                    store.updateProfile { $0.prefersHealthKit = false }
                }
            }
        }
        .alert("Reset Today's Data", isPresented: $showResetTodayAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                store.resetToday()
            }
        } message: {
            Text("This will remove all hydration entries logged today. This cannot be undone.")
        }
        .alert("Clear All Data", isPresented: $showClearAllDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Everything", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your hydration history, achievements, and reset your profile. This cannot be undone.")
        }
        .alert("Run Onboarding Again", isPresented: $showResetOnboardingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restart", role: .destructive) {
                hasOnboarded = false
                hasOnboardedLocally = false
            }
        } message: {
            Text("This will take you through onboarding again the next time you open the app.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isDismissible: true)
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            TextField("Name", text: Binding(
                get: { store.profile.name },
                set: { value in
                    store.updateProfile { $0.name = value }
                }
            ))
            .textInputAutocapitalization(.words)
            .disableAutocorrection(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weight")
                    Spacer()
                    Text("\(Int(store.profile.unitSystem.amountFromKG(store.profile.weightKg))) \(store.profile.unitSystem.bodyWeightUnit)")
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { store.profile.unitSystem.amountFromKG(store.profile.weightKg) },
                        set: { value in
                            store.updateProfile { profile in
                                profile.weightKg = profile.unitSystem.kg(from: value)
                            }
                        }
                    ),
                    in: store.profile.unitSystem == .metric ? 40...140 : 90...300,
                    step: store.profile.unitSystem == .metric ? 1 : 2
                )
                .tint(Theme.lagoon)
            }

            Picker("Units", selection: Binding(
                get: { store.profile.unitSystem },
                set: { value in
                    store.updateProfile { $0.unitSystem = value }
                    if customGoalEnabled {
                        let mlValue = store.profile.customGoalML ?? store.dailyGoal.totalML
                        customGoalValue = store.profile.unitSystem.amount(fromML: mlValue)
                    }
                }
            )) {
                Text("Metric").tag(UnitSystem.metric)
                Text("Imperial").tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)

            Picker("Activity Level", selection: Binding(
                get: { store.profile.activityLevel },
                set: { value in
                    store.updateProfile { $0.activityLevel = value }
                }
            )) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: appThemeBinding) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.label)
                        .tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            Button("Manage Subscription") {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var goalSection: some View {
        Section("Daily Goal") {
            Toggle("Use custom goal", isOn: $customGoalEnabled)
                .onChange(of: customGoalEnabled) { _, enabled in
                    store.updateProfile { profile in
                        profile.customGoalML = enabled ? profile.unitSystem.ml(from: customGoalValue) : nil
                    }
                }

            if customGoalEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Target")
                        Spacer()
                        Text("\(Int(customGoalValue)) \(store.profile.unitSystem.volumeUnit)")
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $customGoalValue,
                        in: store.profile.unitSystem == .metric ? 1500...4500 : 50...150,
                        step: store.profile.unitSystem == .metric ? 50 : 2
                    )
                    .tint(Theme.sun)
                    .onChange(of: customGoalValue) { _, value in
                        store.updateProfile { profile in
                            profile.customGoalML = profile.unitSystem.ml(from: value)
                        }
                    }
                }
            }

            Toggle(isOn: Binding(
                get: { store.profile.prefersWeatherGoal },
                set: { value in
                    guard subscriptionManager.isPro || !value else {
                        showPaywall = true
                        return
                    }
                    if !value {
                        pendingEnableWeatherAdjustment = false
                        store.updateProfile { $0.prefersWeatherGoal = false }
                        return
                    }

                    if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                        pendingEnableWeatherAdjustment = false
                        store.updateProfile { $0.prefersWeatherGoal = false }
                        openAppSettings()
                        return
                    }

                    guard locationEnabled else {
                        pendingEnableWeatherAdjustment = true
                        store.updateProfile { $0.prefersWeatherGoal = false }
                        locationManager.requestPermission()
                        locationManager.requestLocation()
                        return
                    }

                    pendingEnableWeatherAdjustment = false
                    store.updateProfile { $0.prefersWeatherGoal = true }
                }
            )) {
                HStack {
                    Label("Weather adjustment", systemImage: "cloud.sun.fill")
                }
            }
            .tint(Theme.mint)

            Toggle(isOn: Binding(
                get: { store.profile.prefersHealthKit },
                set: { value in
                    guard subscriptionManager.isPro || !value else {
                        showPaywall = true
                        return
                    }
                    if !value {
                        pendingEnableWorkoutAdjustment = false
                        store.updateProfile { $0.prefersHealthKit = false }
                        return
                    }

                    if healthKit.isPermissionDenied {
                        pendingEnableWorkoutAdjustment = false
                        store.updateProfile { $0.prefersHealthKit = false }
                        openAppSettings()
                        return
                    }

                    guard healthKit.isAuthorized else {
                        pendingEnableWorkoutAdjustment = true
                        store.updateProfile { $0.prefersHealthKit = false }
                        Task {
                            await healthKit.requestAuthorization()
                            await healthKit.refreshAuthorizationStatus()
                            if pendingEnableWorkoutAdjustment && subscriptionManager.isPro && healthKit.isAuthorized {
                                store.updateProfile { $0.prefersHealthKit = true }
                            }
                            pendingEnableWorkoutAdjustment = false
                        }
                        return
                    }

                    pendingEnableWorkoutAdjustment = false
                    store.updateProfile { $0.prefersHealthKit = true }
                }
            )) {
                HStack {
                    Label("Workout adjustment", systemImage: "figure.run")
                }
            }
            .tint(Theme.mint)
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            DatePicker("Wake", selection: $wakeTime, displayedComponents: .hourAndMinute)
            DatePicker("Sleep", selection: $sleepTime, displayedComponents: .hourAndMinute)
        }
        .onChange(of: wakeTime) {
            updateSchedule()
        }
        .onChange(of: sleepTime) {
            updateSchedule()
        }
    }

    private var reminderSection: some View {
        Section("Reminders") {
            Toggle("Enable reminders", isOn: Binding(
                get: { store.profile.remindersEnabled },
                set: { value in
                    store.updateProfile { $0.remindersEnabled = value }
                    rescheduleReminders()
                }
            ))

            Toggle("Smart reminders", isOn: Binding(
                get: { store.profile.smartRemindersEnabled },
                set: { value in
                    store.updateProfile { $0.smartRemindersEnabled = value }
                    rescheduleReminders()
                }
            ))

            Stepper(value: Binding(
                get: { store.profile.dailyReminderCount },
                set: { value in
                    store.updateProfile { $0.dailyReminderCount = value }
                    rescheduleReminders()
                }
            ), in: 3...12) {
                HStack {
                    Text("Reminders per day")
                    Spacer()
                    Text("\(store.profile.dailyReminderCount)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
            Toggle(isOn: Binding(
                get: { healthKit.isAuthorized },
                set: { _ in
                    if healthKit.isAuthorized || healthKit.isPermissionDenied {
                        openAppSettings()
                    } else {
                        Task { await healthKit.requestAuthorization() }
                    }
                }
            )) {
                Label("HealthKit", systemImage: "heart.fill")
            }
            .tint(Theme.mint)

            if healthKit.isAuthorized {
                Button("Sync HealthKit Now") {
                    Task {
                        guard let entries = await healthKit.fetchRecentWaterEntries(days: 7) else { return }
                        await MainActor.run {
                            store.syncHealthKitEntriesRange(entries, days: 7)
                        }
                    }
                }
            }

            Toggle(isOn: Binding(
                get: { locationEnabled },
                set: { _ in
                    if locationEnabled || locationManager.authorizationStatus == .denied {
                        openAppSettings()
                    } else {
                        locationManager.requestPermission()
                    }
                }
            )) {
                Label("Location", systemImage: "location.fill")
            }
            .tint(Theme.mint)

            Toggle(isOn: Binding(
                get: { notificationEnabled },
                set: { _ in
                    if notificationEnabled || notifier.authorizationStatus == .denied {
                        openAppSettings()
                    } else {
                        Task { await notifier.requestAuthorization() }
                    }
                }
            )) {
                Label("Notifications", systemImage: "bell.badge.fill")
            }
            .tint(Theme.mint)
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var locationEnabled: Bool {
        locationManager.authorizationStatus == .authorizedAlways ||
        locationManager.authorizationStatus == .authorizedWhenInUse
    }

    private var notificationEnabled: Bool {
        switch notifier.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section("Data Management") {
            Button {
                exportData()
            } label: {
                HStack {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            Button(role: .destructive) {
                showResetTodayAlert = true
            } label: {
                Label("Reset Today's Entries", systemImage: "arrow.counterclockwise")
            }

            Button(role: .destructive) {
                showClearAllDataAlert = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }

            Button(role: .destructive) {
                showResetOnboardingAlert = true
            } label: {
                Label("Run Onboarding Again", systemImage: "arrow.clockwise.circle")
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About Thirsty.ai") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Thirsty.ai")
                    .font(.headline.weight(.semibold))
                Text("Smarter hydration, personalized to your day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text(appBuild)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("What's New")
                    .font(.subheadline.weight(.semibold))
                Text("Adaptive goals, richer insights, and improved reminders based on your routine.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            Link(destination: websiteURL) {
                aboutRow(title: "Website", systemImage: "globe")
            }

            Link(destination: privacyPolicyURL) {
                aboutRow(title: "Privacy Policy", systemImage: "hand.raised.fill")
            }

            Link(destination: termsOfUseURL) {
                aboutRow(title: "Terms of Use", systemImage: "doc.text.fill")
            }

            Link(destination: weatherAttributionURL) {
                aboutRow(title: " Weather Legal Attribution", systemImage: "cloud.sun.fill")
            }

            Link(destination: contactSupportURL) {
                aboutRow(title: "Contact Support", systemImage: "envelope.fill")
            }
        }
    }

    private func aboutRow(title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    private var appThemeBinding: Binding<AppTheme> {
        Binding(
            get: { appTheme },
            set: { newTheme in
                appThemeRawValue = newTheme.rawValue
            }
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var privacyPolicyURL: URL {
        URL(string: "https://docs.google.com/document/d/1g8aUo5wOtiWswv1djQhdrgtMhgYgR1lAoCPQXKBt-uI/edit?usp=sharing")!
    }

    private var termsOfUseURL: URL {
        URL(string: "https://docs.google.com/document/d/1rdGDBrVK0fN8HQMsBLWOgTn61S_7tORzhsphW-GiGQ8/edit?usp=sharing")!
    }

    private var websiteURL: URL {
        URL(string: "https://flutterly.co.uk")!
    }

    private var weatherAttributionURL: URL {
        URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
    }

    private var contactSupportURL: URL {
        URL(string: "mailto:anoop@flutterly.co.uk?subject=Thirsty.ai%20Support")!
    }

    private func exportData() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let snapshot = store.persistedStateSnapshot
        guard let data = try? encoder.encode(snapshot) else { return }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("ThirstyAI-Export.json")
        do {
            try data.write(to: fileURL, options: .atomic)
            exportURL = fileURL
            showExportSheet = true
        } catch {
            print("Export failed: \(error)")
        }
    }

    private func clearAllData() {
        store.resetAllData()
        hydrateLocalStateFromProfile()
    }

    private func syncAdaptiveSettingsWithPermissions() {
        if store.profile.prefersWeatherGoal && !locationEnabled {
            store.updateProfile { $0.prefersWeatherGoal = false }
        }
        if store.profile.prefersHealthKit && !healthKit.isAuthorized {
            store.updateProfile { $0.prefersHealthKit = false }
        }
    }

    private func hydrateLocalStateFromProfile() {
        if let custom = store.profile.customGoalML {
            customGoalEnabled = true
            customGoalValue = store.profile.unitSystem.amount(fromML: custom)
        } else {
            customGoalEnabled = false
            customGoalValue = store.profile.unitSystem.amount(fromML: store.dailyGoal.baseML)
        }

        wakeTime = dateFromMinutes(store.profile.wakeMinutes)
        sleepTime = dateFromMinutes(store.profile.sleepMinutes)
    }

    private func updateSchedule() {
        let wakeMinutes = minutes(from: wakeTime)
        let sleepMinutes = minutes(from: sleepTime)

        store.updateProfile { profile in
            profile.wakeMinutes = wakeMinutes
            profile.sleepMinutes = sleepMinutes
        }

        rescheduleReminders()
    }

    private func rescheduleReminders() {
        notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
    }

    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        let hour = minutes / 60
        let minute = minutes % 60
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

#if DEBUG
#Preview("Settings") {
    PreviewEnvironment {
        SettingsView()
    }
}
#endif
