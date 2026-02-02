import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    @Published var isAuthorized: Bool = false

    func requestAuthorization() async {
        guard isAvailable else { return }
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let workoutType = HKObjectType.workoutType()
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

        let shareTypes: Set = [waterType]
        let readTypes: Set = [waterType, workoutType, energyType]

        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            isAuthorized = true
        } catch {
            isAuthorized = false
            print("HealthKit auth failed: \(error)")
        }
    }

    func fetchTodayWorkoutSummary() async -> WorkoutSummary {
        guard isAvailable else { return .empty }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        let workoutMinutes = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let workouts = samples as? [HKWorkout] ?? []
                let totalMinutes = workouts.reduce(0.0) { $0 + $1.duration / 60.0 }
                continuation.resume(returning: totalMinutes)
            }
            healthStore.execute(query)
        }

        let energy = await fetchActiveEnergy(predicate: predicate)
        return WorkoutSummary(exerciseMinutes: workoutMinutes, activeEnergyKcal: energy)
    }

    func saveWaterIntake(ml: Double, date: Date = Date()) async {
        guard isAvailable else { return }
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
        do {
            try await healthStore.save(sample)
        } catch {
            print("Failed to save water sample: \(error)")
        }
    }

    private func fetchActiveEnergy(predicate: NSPredicate) async -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                let kcal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: kcal)
            }
            healthStore.execute(query)
        }
    }
}
