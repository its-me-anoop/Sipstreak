# iOS Widgets Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Small, Medium, and Large home screen widgets that show hydration progress, goal, streak, and recent entries, sharing data with the main app via App Groups.

**Architecture:** The main app's `PersistenceService` is updated to write `WaterQuestState.json` to a shared App Group container. A new WidgetKit extension reads this JSON via a lightweight `WidgetDataProvider`. The main app triggers timeline reloads on every data change. A `sipli://add-intake` deep link lets the medium/large widget open the add-intake sheet.

**Tech Stack:** WidgetKit, SwiftUI, App Groups, JSON Codable

---

## Task 1: Add App Group entitlement to the main app

**Files:**
- Modify: `WaterQuest/Supporting/WaterQuest.entitlements`

**Step 1: Add App Group to entitlements**

Add the `com.apple.security.application-groups` key to the existing entitlements file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.healthkit</key>
	<true/>
	<key>com.apple.developer.weatherkit</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.waterquest.hydration</string>
	</array>
</dict>
</plist>
```

**Step 2: Enable App Groups in Xcode project**

In Xcode: select WaterQuest target > Signing & Capabilities > + Capability > App Groups > add `group.com.waterquest.hydration`. This updates the provisioning profile. Verify the entitlements file matches.

**Step 3: Build to verify**

Run: `xcodebuild build` via XcodeBuildMCP
Expected: Build succeeds

**Step 4: Commit**

```
feat: add App Group entitlement to main app
```

---

## Task 2: Update PersistenceService to use shared App Group container

**Files:**
- Modify: `WaterQuest/Services/PersistenceService.swift`

**Step 1: Update PersistenceService to write to the shared container**

Replace the entire `PersistenceService` with:

```swift
import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    static let appGroupID = "group.com.waterquest.hydration"

    private let url: URL

    init(filename: String = "WaterQuestState.json") {
        let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: PersistenceService.appGroupID
        )
        let directory = groupURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        self.url = directory.appendingPathComponent(filename)

        // One-time migration from old location
        Self.migrateIfNeeded(to: self.url, filename: filename)
    }

    func load<T: Decodable>(_ type: T.Type, fallback: T) -> T {
        guard let data = try? Data(contentsOf: url) else { return fallback }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(T.self, from: data)) ?? fallback
    }

    func save<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(value)
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("Failed to save Sipli state: \(error)")
            #endif
        }
    }

    /// Moves the JSON file from the old Application Support location to the
    /// shared App Group container. Runs once — if the old file doesn't exist
    /// or the new file already exists, this is a no-op.
    private static func migrateIfNeeded(to newURL: URL, filename: String) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: newURL.path) else { return }

        guard let oldDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let oldURL = oldDir.appendingPathComponent(filename)
        guard fm.fileExists(atPath: oldURL.path) else { return }

        do {
            try fm.moveItem(at: oldURL, to: newURL)
        } catch {
            #if DEBUG
            print("Migration failed, copying instead: \(error)")
            #endif
            try? fm.copyItem(at: oldURL, to: newURL)
        }
    }
}
```

**Step 2: Build and run to verify migration**

Run: build via XcodeBuildMCP
Expected: Build succeeds. On first run, existing data migrates to the App Group container.

**Step 3: Commit**

```
feat: move PersistenceService to shared App Group container
```

---

## Task 3: Reload widget timelines on data changes

**Files:**
- Modify: `WaterQuest/Services/HydrationStore.swift`

**Step 1: Add WidgetKit import and reload call**

At the top of `HydrationStore.swift`, add:

```swift
import WidgetKit
```

At the end of the `persist()` method (after `persistence.save(state)`), add:

```swift
WidgetCenter.shared.reloadAllTimelines()
```

So the method becomes:

```swift
private func persist() {
    let state = PersistedState(
        entries: entries,
        profile: profile,
        lastWeather: lastWeather,
        lastWorkout: lastWorkout
    )
    persistence.save(state)
    WidgetCenter.shared.reloadAllTimelines()
}
```

**Step 2: Build to verify**

Expected: Build succeeds

**Step 3: Commit**

```
feat: reload widget timelines on hydration data changes
```

---

## Task 4: Add deep link handling for sipli://add-intake

**Files:**
- Modify: `WaterQuest/Supporting/Info.plist` — add URL scheme
- Modify: `WaterQuest/App/WaterQuestApp.swift` — handle URL
- Modify: `WaterQuest/Views/MainTabView.swift` — observe deep link state

**Step 1: Register the URL scheme in Info.plist**

Add to Info.plist:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>sipli</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.waterquest.hydration</string>
    </dict>
</array>
```

**Step 2: Handle URL in WaterQuestApp.swift**

Add an `@State` var and `.onOpenURL` to `WaterQuestApp`:

```swift
@State private var deepLinkAddIntake = false
```

On the `WindowGroup`'s root `ZStack`, add:

```swift
.onOpenURL { url in
    if url.scheme == "sipli" && url.host == "add-intake" {
        deepLinkAddIntake = true
    }
}
.environment(\.deepLinkAddIntake, deepLinkAddIntake)
.onChange(of: deepLinkAddIntake) {
    if !deepLinkAddIntake { return }
    // Reset after MainTabView picks it up
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        deepLinkAddIntake = false
    }
}
```

Create an `EnvironmentKey` — add to the bottom of `WaterQuestApp.swift` (or a small extension):

```swift
private struct DeepLinkAddIntakeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var deepLinkAddIntake: Bool {
        get { self[DeepLinkAddIntakeKey.self] }
        set { self[DeepLinkAddIntakeKey.self] = newValue }
    }
}
```

**Step 3: Open AddIntakeView from MainTabView when deep link fires**

In `MainTabView.swift`, add:

```swift
@Environment(\.deepLinkAddIntake) private var deepLinkAddIntake
```

And add an `.onChange` modifier:

```swift
.onChange(of: deepLinkAddIntake) {
    if deepLinkAddIntake {
        showAddIntake = true
    }
}
```

**Step 4: Build to verify**

Expected: Build succeeds

**Step 5: Commit**

```
feat: add sipli://add-intake deep link for widget quick-add
```

---

## Task 5: Create the Widget Extension target and shared file references

**Files:**
- Create: `SipliWidget/` directory
- Create: `SipliWidget/Supporting/SipliWidget.entitlements`
- Create: `SipliWidget/SipliWidgetBundle.swift`

This task is done in Xcode because adding a widget extension target requires modifying the Xcode project file (targets, build phases, signing, file membership).

**Step 1: Add Widget Extension target in Xcode**

File > New > Target > Widget Extension.
- Product Name: `SipliWidget`
- Team: K6623R3GP5 (auto)
- Bundle Identifier: `com.waterquest.hydration.widget`
- Include Configuration App Intent: NO (uncheck)

This creates the `SipliWidget/` directory with boilerplate files.

**Step 2: Add App Group to the widget extension**

Select the SipliWidget target > Signing & Capabilities > + Capability > App Groups > add `group.com.waterquest.hydration`.

The generated entitlements file at `SipliWidget/Supporting/SipliWidget.entitlements` should contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.waterquest.hydration</string>
	</array>
</dict>
</plist>
```

**Step 3: Add shared source files to widget target**

In Xcode, select each of these files in the Project Navigator and in the File Inspector (right panel), check the `SipliWidget` target membership:

- `WaterQuest/Services/PersistenceService.swift`
- `WaterQuest/Services/GoalCalculator.swift`
- `WaterQuest/Services/Formatters.swift`
- `WaterQuest/Models/HydrationEntry.swift`
- `WaterQuest/Models/UserProfile.swift`
- `WaterQuest/Models/FluidType.swift`
- `WaterQuest/Models/GoalBreakdown.swift`
- `WaterQuest/Models/UnitSystem.swift`
- `WaterQuest/Models/WeatherSnapshot.swift`
- `WaterQuest/Models/WorkoutSummary.swift`
- `WaterQuest/Components/Theme.swift`

**Step 4: Delete boilerplate widget files**

Delete the auto-generated widget Swift files from `SipliWidget/` (we'll write our own in the next tasks). Keep only `SipliWidget.entitlements` and `Assets.xcassets` if created.

**Step 5: Build to verify shared files compile in the widget target**

Expected: Build succeeds (the widget won't have an entry point yet — that's fine, add a placeholder `@main` if needed to pass the build)

**Step 6: Commit**

```
feat: add SipliWidget extension target with shared file references
```

---

## Task 6: Create WidgetDataProvider (reads shared JSON)

**Files:**
- Create: `SipliWidget/WidgetDataProvider.swift`

**Step 1: Create WidgetDataProvider.swift**

```swift
import Foundation

struct WidgetData {
    let todayEntries: [HydrationEntry]
    let todayTotalML: Double
    let goal: GoalBreakdown
    let streak: Int
    let unitSystem: UnitSystem
}

enum WidgetDataProvider {
    static func load() -> WidgetData {
        let persistence = PersistenceService()
        let state = persistence.load(PersistedState.self, fallback: .default)

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let todayEntries = state.entries
            .filter { calendar.isDate($0.date, inSameDayAs: startOfToday) }
            .sorted { $0.date > $1.date }

        let todayTotalML = todayEntries.reduce(0) { $0 + $1.effectiveML }

        let goal = GoalCalculator.dailyGoal(
            profile: state.profile,
            weather: state.lastWeather,
            workout: state.lastWorkout
        )

        let streak = calculateStreak(entries: state.entries, goalML: goal.totalML)

        return WidgetData(
            todayEntries: todayEntries,
            todayTotalML: todayTotalML,
            goal: goal,
            streak: streak,
            unitSystem: state.profile.unitSystem
        )
    }

    private static func calculateStreak(entries: [HydrationEntry], goalML: Double) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if today's goal is met; if not, start from yesterday
        let todayTotal = entries
            .filter { calendar.isDate($0.date, inSameDayAs: checkDate) }
            .reduce(0) { $0 + $1.effectiveML }

        if todayTotal < goalML {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        for dayOffset in 0..<90 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: checkDate) else { break }
            let dayTotal = entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.effectiveML }

            if dayTotal >= goalML {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }
}
```

**Step 2: Make PersistedState accessible to the widget**

`PersistedState` is currently declared in `HydrationStore.swift` which is NOT shared with the widget (it uses `@MainActor`, `ObservableObject`, `WidgetKit` import). We need to move `PersistedState` to its own file shared with both targets.

Create: `WaterQuest/Models/PersistedState.swift`

```swift
import Foundation

struct PersistedState: Codable {
    var entries: [HydrationEntry]
    var profile: UserProfile
    var lastWeather: WeatherSnapshot?
    var lastWorkout: WorkoutSummary

    private enum CodingKeys: String, CodingKey {
        case entries, profile, lastWeather, lastWorkout, gameState, manualWeather
    }

    init(entries: [HydrationEntry], profile: UserProfile, lastWeather: WeatherSnapshot?, lastWorkout: WorkoutSummary) {
        self.entries = entries
        self.profile = profile
        self.lastWeather = lastWeather
        self.lastWorkout = lastWorkout
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries = try c.decode([HydrationEntry].self, forKey: .entries)
        profile = try c.decode(UserProfile.self, forKey: .profile)
        lastWeather = try c.decodeIfPresent(WeatherSnapshot.self, forKey: .lastWeather)
        lastWorkout = try c.decodeIfPresent(WorkoutSummary.self, forKey: .lastWorkout) ?? .empty
    }

    static let `default` = PersistedState(
        entries: [],
        profile: .default,
        lastWeather: nil,
        lastWorkout: .empty
    )
}
```

Then remove the `PersistedState` struct from `HydrationStore.swift`.

Add `PersistedState.swift` to both the WaterQuest and SipliWidget target memberships.

**Step 3: Build both targets to verify**

Expected: Both targets build successfully

**Step 4: Commit**

```
feat: add WidgetDataProvider and extract PersistedState to shared model
```

---

## Task 7: Create the Timeline Provider

**Files:**
- Create: `SipliWidget/SipliTimelineProvider.swift`

**Step 1: Create the timeline provider**

```swift
import WidgetKit

struct SipliEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct SipliTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SipliEntry {
        SipliEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SipliEntry) -> Void) {
        let entry = SipliEntry(date: .now, data: WidgetDataProvider.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SipliEntry>) -> Void) {
        let data = WidgetDataProvider.load()
        let entry = SipliEntry(date: .now, data: data)

        // Refresh in 15 minutes or at midnight (whichever is sooner)
        let calendar = Calendar.current
        let fifteenMin = calendar.date(byAdding: .minute, value: 15, to: .now) ?? .now
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let nextRefresh = min(fifteenMin, midnight)

        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

extension WidgetData {
    static let placeholder = WidgetData(
        todayEntries: [],
        todayTotalML: 1250,
        goal: GoalBreakdown(baseML: 2450, weatherAdjustmentML: 0, workoutAdjustmentML: 0, totalML: 2450),
        streak: 3,
        unitSystem: .metric
    )
}
```

**Step 2: Build to verify**

Expected: Build succeeds

**Step 3: Commit**

```
feat: add WidgetKit timeline provider with 15-minute refresh
```

---

## Task 8: Create SmallWidgetView

**Files:**
- Create: `SipliWidget/Views/SmallWidgetView.swift`

**Step 1: Create the small widget view**

```swift
import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let data: WidgetData

    private var progress: Double {
        min(1, data.todayTotalML / max(1, data.goal.totalML))
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(Formatters.percentString(progress))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }
            .frame(width: 70, height: 70)

            Text("\(Formatters.shortVolume(ml: data.todayTotalML, unit: data.unitSystem)) / \(Formatters.volumeString(ml: data.goal.totalML, unit: data.unitSystem))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

**Step 2: Build to verify**

Expected: Build succeeds

**Step 3: Commit**

```
feat: add small widget view with progress ring
```

---

## Task 9: Create MediumWidgetView

**Files:**
- Create: `SipliWidget/Views/MediumWidgetView.swift`

**Step 1: Create the medium widget view**

```swift
import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let data: WidgetData

    private var progress: Double {
        min(1, data.todayTotalML / max(1, data.goal.totalML))
    }

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(Formatters.percentString(progress))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }
            .frame(width: 70, height: 70)

            // Stats
            VStack(alignment: .leading, spacing: 6) {
                Text(Formatters.volumeString(ml: data.todayTotalML, unit: data.unitSystem))
                    .font(.system(.title3, design: .rounded).weight(.heavy))

                Text("of \(Formatters.volumeString(ml: data.goal.totalML, unit: data.unitSystem))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if data.streak > 0 {
                    Label("\(data.streak)-day streak", systemImage: "flame.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Quick-add button
            Link(destination: URL(string: "sipli://add-intake")!) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

**Step 2: Build to verify**

Expected: Build succeeds

**Step 3: Commit**

```
feat: add medium widget view with stats and quick-add button
```

---

## Task 10: Create LargeWidgetView

**Files:**
- Create: `SipliWidget/Views/LargeWidgetView.swift`

**Step 1: Create the large widget view**

```swift
import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let data: WidgetData

    private var progress: Double {
        min(1, data.todayTotalML / max(1, data.goal.totalML))
    }

    private var recentEntries: [HydrationEntry] {
        Array(data.todayEntries.prefix(5))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: ring + stats
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Text(Formatters.percentString(progress))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.volumeString(ml: data.todayTotalML, unit: data.unitSystem))
                        .font(.system(.title3, design: .rounded).weight(.heavy))

                    Text("of \(Formatters.volumeString(ml: data.goal.totalML, unit: data.unitSystem))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if data.streak > 0 {
                    VStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(data.streak)")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                        Text("days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Recent entries
            if recentEntries.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "drop")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No entries yet today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(recentEntries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.fluidType.iconName)
                            .font(.caption)
                            .foregroundStyle(entry.fluidType.color)
                            .frame(width: 20)

                        Text(entry.fluidType.displayName)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        Text(Formatters.volumeString(ml: entry.volumeML, unit: data.unitSystem))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()

                        Text(Self.timeFormatter.string(from: entry.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }

            Spacer(minLength: 0)

            // Quick-add button
            Link(destination: URL(string: "sipli://add-intake")!) {
                HStack {
                    Spacer()
                    Label("Log Water", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Spacer()
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

**Step 2: Build to verify**

Expected: Build succeeds

**Step 3: Commit**

```
feat: add large widget view with entry log and quick-add
```

---

## Task 11: Create the Widget entry point and bundle

**Files:**
- Create: `SipliWidget/SipliWidget.swift`

**Step 1: Create the widget definition and bundle**

```swift
import SwiftUI
import WidgetKit

struct SipliWidget: Widget {
    let kind = "SipliWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SipliTimelineProvider()) { entry in
            switch entry.context.family {
            case .systemSmall:
                SmallWidgetView(data: entry.data)
            case .systemMedium:
                MediumWidgetView(data: entry.data)
            case .systemLarge:
                LargeWidgetView(data: entry.data)
            default:
                SmallWidgetView(data: entry.data)
            }
        }
        .configurationDisplayName("Sipli")
        .description("Track your daily hydration progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct SipliWidgetBundle: WidgetBundle {
    var body: some Widget {
        SipliWidget()
    }
}
```

Note: The `entry.context.family` approach won't work because `TimelineEntry` doesn't carry context. Instead, the widget view should receive the entry and WidgetKit handles sizing. Update the configuration to use a single view that switches on `@Environment(\.widgetFamily)`:

Replace the widget body with:

```swift
struct SipliWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let data: WidgetData

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: data)
        case .systemMedium:
            MediumWidgetView(data: data)
        case .systemLarge:
            LargeWidgetView(data: data)
        default:
            SmallWidgetView(data: data)
        }
    }
}

struct SipliWidget: Widget {
    let kind = "SipliWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SipliTimelineProvider()) { entry in
            SipliWidgetEntryView(data: entry.data)
        }
        .configurationDisplayName("Sipli")
        .description("Track your daily hydration progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct SipliWidgetBundle: WidgetBundle {
    var body: some Widget {
        SipliWidget()
    }
}
```

**Step 2: Build the widget target**

Expected: Build succeeds for both targets

**Step 3: Commit**

```
feat: add SipliWidget entry point and bundle
```

---

## Task 12: Build, run, and verify on simulator

**Step 1: Build both targets**

Build the full project via XcodeBuildMCP.

**Step 2: Run on simulator**

Launch the app on iPhone 16 Pro simulator. Add the widget to the home screen:
- Long-press home screen > "+" > search "Sipli" > add each size

**Step 3: Verify**

- Small widget: shows progress ring and total/goal
- Medium widget: shows ring, stats, streak, "+" button
- Large widget: shows ring, stats, entries list, "Log Water" button
- Tapping "+" on medium/large opens the app to add-intake
- Adding a log in the app updates the widget within seconds

**Step 4: Final commit**

```
feat: complete iOS widget extension with Small, Medium, Large sizes
```
