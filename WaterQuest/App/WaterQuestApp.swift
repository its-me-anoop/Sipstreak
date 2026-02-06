import SwiftUI

@main
struct WaterQuestApp: App {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
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
                store.setPremiumAccess(subscriptionManager.hasActiveSubscription)
                await notifier.refreshAuthorizationStatus()
                notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
                await subscriptionManager.initialise()
                store.setPremiumAccess(subscriptionManager.hasActiveSubscription)
                if subscriptionManager.hasActiveSubscription {
                    await healthKit.refreshAuthorizationStatus()
                } else {
                    healthKit.stopWaterIntakeObserver()
                }
                notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
                _ = subscriptionManager.startTransactionListener()
                await synchronizeWithServer()
            }
            .task(id: store.canUseWorkoutAdjustment) {
                if store.canUseWorkoutAdjustment {
                    await startHealthKitAutoSync()
                } else {
                    healthKit.stopWaterIntakeObserver()
                }
            }
            .task(id: syncTrigger) {
                guard syncTrigger > 0, !isApplyingRemoteSync else { return }
                try? await Task.sleep(for: .seconds(1.0))
                guard !isApplyingRemoteSync else { return }
                await synchronizeWithServer()
            }
            .onChange(of: subscriptionManager.hasActiveSubscription) { _, hasSubscription in
                store.setPremiumAccess(hasSubscription)
                if !store.canUseWorkoutAdjustment {
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
            .onChange(of: appTheme) { _, _ in
                guard !isApplyingRemoteSync else { return }
                store.touchForSync()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await subscriptionManager.refreshStatus()
                        store.setPremiumAccess(subscriptionManager.hasActiveSubscription)
                        if subscriptionManager.hasActiveSubscription {
                            await healthKit.refreshAuthorizationStatus()
                        }
                        await refreshHealthKitWaterEntries()
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
    }

    @MainActor
    private func refreshHealthKitWaterEntries() async {
        guard store.canUseWorkoutAdjustment else { return }
        if let entries = await healthKit.fetchRecentWaterEntries(days: 7) {
            store.syncHealthKitEntriesRange(entries, days: 7)
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
                appTheme = syncedTheme
            }
            notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
        }
    }
}
