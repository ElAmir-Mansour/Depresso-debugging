import HealthKit
import SwiftUI

final class HealthKitManager {
    private let healthStore = HKHealthStore()

    private let typesToRead: Set<HKSampleType> = [
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.stepCount),
        HKCategoryType(.sleepAnalysis),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate)
    ]

    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(
            toShare: [],
            read: typesToRead
        )
    }

    // MARK: - Fetch Daily Metrics
    func fetchDailyMetrics() async -> [HealthMetric] {
        var metrics: [HealthMetric] = []
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!

        // Steps
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let steps = await fetchSumQuantity(for: stepType, from: todayStart, to: todayEnd, unit: .count())
            metrics.append(HealthMetric(type: .steps, value: steps ?? 0.0, date: Date()))
        }

        // Calories
        if let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let calories = await fetchSumQuantity(for: calorieType, from: todayStart, to: todayEnd, unit: .kilocalorie())
            metrics.append(HealthMetric(type: .calories, value: calories ?? 0.0, date: Date()))
        }

        // Heart Rate
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            let avgHeartRate = await fetchAverageQuantity(for: heartRateType, from: todayStart, to: todayEnd, unit: .count().unitDivided(by: .minute()))
            if let avgHeartRate = avgHeartRate {
                metrics.append(HealthMetric(type: .heartRate, value: avgHeartRate, date: Date()))
            } else {
                let latestHR = await fetchMostRecentQuantity(for: heartRateType, unit: .count().unitDivided(by: .minute()))
                metrics.append(HealthMetric(type: .heartRate, value: latestHR ?? 0.0, date: Date()))
            }
        } else {
            metrics.append(HealthMetric(type: .heartRate, value: 0.0, date: Date()))
        }

        return metrics
    }

    // MARK: - Fetch Weekly Step Data
    func fetchWeeklyStepData() async -> [StepData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }

        let anchorDate = calendar.startOfDay(for: startDate)
        var interval = DateComponents()
        interval.day = 1

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: calendar.date(byAdding: .day, value: 1, to: today), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { query, results, error in
                guard let results = results else {
                    print("Error fetching weekly steps: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: [])
                    return
                }

                var stepsData: [StepData] = []
                results.enumerateStatistics(from: startDate, to: today) { statistics, stop in
                    let count = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0.0
                    stepsData.append(StepData(date: statistics.startDate, count: count))
                }
                continuation.resume(returning: stepsData)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Helper Methods
    private func fetchSumQuantity(for type: HKQuantityType, from start: Date, to end: Date, unit: HKUnit) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)], sortDescriptors: [])

        do {
            let results = try await descriptor.result(for: healthStore)
            let sum = results.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
            return sum
        } catch {
            print("Error fetching sum for \(type.identifier): \(error)")
            return nil
        }
    }

    private func fetchAverageQuantity(for type: HKQuantityType, from start: Date, to end: Date, unit: HKUnit) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)], sortDescriptors: [])

        do {
            let results = try await descriptor.result(for: healthStore)
            guard !results.isEmpty else { return nil }
            let sum = results.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
            return sum / Double(results.count)
        } catch {
            print("Error fetching average for \(type.identifier): \(error)")
            return nil
        }
    }

    private func fetchMostRecentQuantity(for type: HKQuantityType, unit: HKUnit) async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            return results.first?.quantity.doubleValue(for: unit)
        } catch {
            print("Error fetching most recent for \(type.identifier): \(error)")
            return nil
        }
    }
}

// MARK: - Data Models
struct HRVReading: Identifiable, Equatable {
    let id = UUID()
    let value: Double
    let date: Date
    let source: String
    var isAbnormal: Bool { value < 20.0 }
}

struct SleepSession: Identifiable, Equatable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let valueRawValue: Int // Store raw value instead of HKCategoryValueSleepAnalysis
    let duration: TimeInterval
    
    var sleepEfficiency: Double {
        // Simplified efficiency calculation
        guard duration > 0 else { return 0 }
        return duration / endDate.timeIntervalSince(startDate)
    }
    
    static func == (lhs: SleepSession, rhs: SleepSession) -> Bool {
        lhs.id == rhs.id &&
        lhs.startDate == rhs.startDate &&
        lhs.endDate == rhs.endDate &&
        lhs.valueRawValue == rhs.valueRawValue &&
        lhs.duration == rhs.duration
    }
}

// MARK: - Error Enum
enum HealthKitError: LocalizedError {
    case notAvailable
    case unauthorized
    case noData
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .unauthorized:
            return "HealthKit access not authorized"
        case .noData:
            return "No health data available for the requested period"
        }
    }
}
