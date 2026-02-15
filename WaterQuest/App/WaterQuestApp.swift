import SwiftUI

@main
struct WaterQuestApp: App {
    @AppStorage("appTheme") private var appThemeRawValue: Int = AppTheme.system.rawValue
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage("WaterQuest.selectedMascot") private var selectedMascotID: String = MascotStyle.ripple.rawValue
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var store = HydrationStore()
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var notifier = NotificationScheduler()
    @StateObject private var locationManager: LocationManager
    @StateObject private var weatherClient: WeatherClient
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var serverSync = ServerSyncService()

    @State private var syncTrigger = 0
    @State private var isApplyingRemoteSync = false

    init() {
        let location = LocationManager()
        _locationManager = StateObject(wrappedValue: location)
        _weatherClient = StateObject(wrappedValue: WeatherClient(locationManager: location))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppWaterBackground().ignoresSafeArea()
                RootView()
            }
            .tint(Theme.lagoon)
            .environmentObject(store)
            .environmentObject(healthKit)
            .environmentObject(notifier)
            .environmentObject(locationManager)
            .environmentObject(weatherClient)
            .environmentObject(subscriptionManager)
            .preferredColorScheme(appTheme.colorScheme)
            .task {
                store.notificationScheduler = notifier
                subscriptionManager.notificationScheduler = notifier
                store.setPremiumAccess(subscriptionManager.isPro)
                await notifier.refreshAuthorizationStatus()
                notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
                await subscriptionManager.initialise()
                store.setPremiumAccess(subscriptionManager.isPro)
                enforcePremiumRestrictions(for: subscriptionManager.isPro)
                if subscriptionManager.isPro {
                    await healthKit.refreshAuthorizationStatus()
                } else {
                    healthKit.stopWaterIntakeObserver()
                }
                notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
                _ = subscriptionManager.startTransactionListener()
                await synchronizeWithServer()
            }
            .task(id: store.canUseWorkoutAdjustment) {
                if hasOnboarded && store.canUseWorkoutAdjustment && healthKit.isAuthorized {
                    await startHealthKitAutoSync()
                } else {
                    healthKit.stopWaterIntakeObserver()
                }
            }
            .task(id: store.canUseWeatherAdjustment) {
                guard hasOnboarded, store.canUseWeatherAdjustment else { return }
                await refreshWeatherSnapshot()
            }
            .task(id: locationManager.lastLocation?.timestamp) {
                guard hasOnboarded, store.canUseWeatherAdjustment else { return }
                await refreshWeatherSnapshot()
            }
            .task(id: syncTrigger) {
                guard syncTrigger > 0, !isApplyingRemoteSync else { return }
                try? await Task.sleep(for: .seconds(1.0))
                guard !isApplyingRemoteSync else { return }
                await synchronizeWithServer()
            }
            .onChange(of: subscriptionManager.isPro) { _, isPro in
                store.setPremiumAccess(isPro)
                enforcePremiumRestrictions(for: isPro)
                if !store.canUseWorkoutAdjustment {
                    healthKit.stopWaterIntakeObserver()
                }
            }
            .onChange(of: healthKit.isAuthorized) { _, isAuthorized in
                guard hasOnboarded else { return }
                if isAuthorized && store.canUseWorkoutAdjustment {
                    Task { await startHealthKitAutoSync() }
                } else if !isAuthorized {
                    healthKit.stopWaterIntakeObserver()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .hydrationStoreDidPersist)) { notification in
                guard let source = notification.userInfo?["source"] as? String,
                      source == HydrationStorePersistSource.local.rawValue else { return }
                syncTrigger += 1
            }
            .onChange(of: hasOnboarded) { _, _ in
                guard !isApplyingRemoteSync else { return }
                store.touchForSync()
            }
            .onChange(of: appThemeRawValue) { _, _ in
                guard !isApplyingRemoteSync else { return }
                store.touchForSync()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await subscriptionManager.refreshStatus()
                        store.setPremiumAccess(subscriptionManager.isPro)
                        enforcePremiumRestrictions(for: subscriptionManager.isPro)
                        if hasOnboarded && subscriptionManager.isPro {
                            await healthKit.refreshAuthorizationStatus()
                        }
                        if hasOnboarded {
                            await refreshHealthKitWaterEntries()
                        }
                        await synchronizeWithServer()
                    }
                } else if phase == .background {
                    Task { await synchronizeWithServer() }
                }
            }
        }
    }

    @MainActor
    private func startHealthKitAutoSync() async {
        await healthKit.startWaterIntakeObserver(days: 7) { entries in
            store.syncHealthKitEntriesRange(entries, days: 7)
        }
        let summary = await healthKit.fetchTodayWorkoutSummary()
        store.updateWorkout(summary)
    }

    @MainActor
    private func refreshHealthKitWaterEntries() async {
        guard store.canUseWorkoutAdjustment else { return }
        let summary = await healthKit.fetchTodayWorkoutSummary()
        store.updateWorkout(summary)
        if let entries = await healthKit.fetchRecentWaterEntries(days: 7) {
            store.syncHealthKitEntriesRange(entries, days: 7)
        }
    }

    @MainActor
    private func refreshWeatherSnapshot() async {
        await weatherClient.refresh()
        if let snapshot = weatherClient.currentWeather {
            store.updateWeather(snapshot)
        } else if locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }

    @MainActor
    private func synchronizeWithServer() async {
        let localState = store.persistedStateSnapshot
        if let remote = await serverSync.synchronize(
            localState: localState,
            hasOnboarded: hasOnboarded,
            appThemeRawValue: appTheme.rawValue
        ) {
            guard remote.updatedAt.timeIntervalSince1970 > localState.lastUpdatedAt.timeIntervalSince1970 + 0.5 else {
                return
            }

            isApplyingRemoteSync = true
            defer { isApplyingRemoteSync = false }

            store.applySyncedState(remote.persistedState)
            hasOnboarded = remote.hasOnboarded
            if let rawValue = remote.appThemeRawValue, let syncedTheme = AppTheme(rawValue: rawValue) {
                appThemeRawValue = syncedTheme.rawValue
            }
            notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
        }
    }

    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    private func enforcePremiumRestrictions(for isPro: Bool) {
        if !isPro, store.profile.prefersWeatherGoal || store.profile.prefersHealthKit {
            store.updateProfile { profile in
                profile.prefersWeatherGoal = false
                profile.prefersHealthKit = false
            }
        }
        enforceMascotAccess(for: isPro)
    }

    private func enforceMascotAccess(for isPro: Bool) {
        let sanitized = MascotStyle.sanitizedSelectionID(from: selectedMascotID, isPro: isPro)
        guard sanitized != selectedMascotID else { return }
        selectedMascotID = sanitized
    }
}
