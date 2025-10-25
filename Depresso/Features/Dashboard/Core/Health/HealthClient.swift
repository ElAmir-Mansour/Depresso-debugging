// In Core/Health/HealthClient.swift
import Foundation
import ComposableArchitecture
import XCTestDynamicOverlay // Needed for XCTFail

// StepData Definition (Remains the same)
struct StepData: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let count: Double

    static var mock: [StepData] { /* ... keep mock data ... */
         let calendar = Calendar.current; let today = calendar.startOfDay(for: .now)
         return (0..<7).map { index -> StepData in
             let date = calendar.date(byAdding: .day, value: -index, to: today)!
             return StepData(date: date, count: Double.random(in: 3000...12000))
         }.reversed()
     }
}

// HealthClient Definition (Remains the same)
struct HealthClient {
    var fetchHealthMetrics: @Sendable () async throws -> [HealthMetric]
    var fetchWeeklySteps: @Sendable () async throws -> [StepData]
    var requestAuthorization: @Sendable () async throws -> Void
}

extension HealthClient: DependencyKey {
    static let liveValue = Self(
        fetchHealthMetrics: {
            let manager = HealthKitManager()
            // **FIX:** Call the actual method name from HealthKitManager
            return await manager.fetchDailyMetrics()
        },
        fetchWeeklySteps: {
            let manager = HealthKitManager()
             // **FIX:** Call the actual method name from HealthKitManager
            return await manager.fetchWeeklyStepData()
        },
        requestAuthorization: {
             let manager = HealthKitManager()
             try await manager.requestAuthorization()
        }
    )

    // Preview and Unimplemented remain the same
     static let previewValue = Self(
         fetchHealthMetrics: { HealthMetric.mock },
         fetchWeeklySteps: { StepData.mock },
         requestAuthorization: { }
     )
     static let unimplemented = Self(
          fetchHealthMetrics: { XCTFail("Unimplemented: HealthClient.fetchHealthMetrics"); return [] },
          fetchWeeklySteps: { XCTFail("Unimplemented: HealthClient.fetchWeeklySteps"); return [] },
          requestAuthorization: { XCTFail("Unimplemented: HealthClient.requestAuthorization") }
     )
}

extension DependencyValues {
    var healthClient: HealthClient {
        get { self[HealthClient.self] }
        set { self[HealthClient.self] = newValue }
    }
}
