import SwiftUI

@main
struct WaterQuestApp: App {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var store = HydrationStore()
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var notifier = NotificationScheduler()
    @StateObject private var locationManager: LocationManager
    @StateObject private var weatherClient: WeatherClient
    @StateObject private var subscriptionManager = SubscriptionManager()

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
                await notifier.refreshAuthorizationStatus()
                await healthKit.refreshAuthorizationStatus()
                notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
                await subscriptionManager.initialise()
                _ = subscriptionManager.startTransactionListener()
            }
            .task(id: store.profile.prefersHealthKit) {
                if store.profile.prefersHealthKit {
                    await startHealthKitAutoSync()
                } else {
                    healthKit.stopWaterIntakeObserver()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await subscriptionManager.refreshStatus()
                        await refreshHealthKitWaterEntries()
                    }
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
        guard store.profile.prefersHealthKit else { return }
        if let entries = await healthKit.fetchRecentWaterEntries(days: 7) {
            store.syncHealthKitEntriesRange(entries, days: 7)
        }
    }
}
