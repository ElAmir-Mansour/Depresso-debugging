//
//  HealthKitClient.swift
//  Depresso
//
//  Created by ElAmir Mansour on 26/10/2025.
//

// Depresso/Core/Clients/HealthKitClient.swift

import ComposableArchitecture
import HealthKit

struct HealthKitClient {
    var requestAuthorization: @Sendable () async throws -> Void
    var fetchTodaySteps: @Sendable () async throws -> Int
    var fetchHeartRate: @Sendable () async throws -> Int
    var fetchActiveEnergy: @Sendable () async throws -> Int
    var fetchWeeklySteps: @Sendable () async throws -> [DailySteps]
    var observeHealthChanges: @Sendable () -> AsyncStream<HealthUpdate>
}

extension HealthKitClient: DependencyKey {
    static let liveValue: HealthKitClient = {
        let healthStore = HKHealthStore()
        
        return HealthKitClient(
            requestAuthorization: {
                let types: Set = [
                    HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                    HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                    HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                ]
                
                try await healthStore.requestAuthorization(toShare: [], read: types)
            },
            fetchTodaySteps: {
                let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
                let now = Date()
                let startOfDay = Calendar.current.startOfDay(for: now)
                
                let predicate = HKQuery.predicateForSamples(
                    withStart: startOfDay,
                    end: now,
                    options: .strictStartDate
                )
                
                let query = HKStatisticsQuery(
                    quantityType: stepType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, result, error in
                    // Handle result
                }
                
                return try await withCheckedThrowingContinuation { continuation in
                    let query = HKStatisticsQuery(
                        quantityType: stepType,
                        quantitySamplePredicate: predicate,
                        options: .cumulativeSum
                    ) { _, result, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                        continuation.resume(returning: Int(steps))
                    }
                    
                    healthStore.execute(query)
                }
            },
            fetchHeartRate: {
                // Similar implementation for heart rate
                return 72 // Placeholder
            },
            fetchActiveEnergy: {
                // Similar implementation
                return 350 // Placeholder
            },
            fetchWeeklySteps: {
                // Fetch last 7 days of step data
                var dailySteps: [DailySteps] = []
                
                for dayOffset in 0..<7 {
                    let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
                    let steps = try await fetchStepsForDate(date, healthStore: healthStore)
                    dailySteps.append(DailySteps(date: date, steps: steps))
                }
                
                return dailySteps.reversed()
            },
            observeHealthChanges: {
                AsyncStream { continuation in
                    // Set up HKObserverQuery for real-time updates
                    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
                    
                    let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, _, error in
                        if error == nil {
                            continuation.yield(.stepsUpdated)
                        }
                    }
                    
                    healthStore.execute(query)
                    
                    continuation.onTermination = { _ in
                        healthStore.stop(query)
                    }
                }
            }
        )
    }()
    
    static let testValue = HealthKitClient(
        requestAuthorization: {},
        fetchTodaySteps: { 8432 },
        fetchHeartRate: { 72 },
        fetchActiveEnergy: { 350 },
        fetchWeeklySteps: {
            (0..<7).map { offset in
                DailySteps(
                    date: Calendar.current.date(byAdding: .day, value: -offset, to: Date())!,
                    steps: Int.random(in: 5000...12000)
                )
            }
        },
        observeHealthChanges: { AsyncStream { _ in } }
    )
}

// Helper function
private func fetchStepsForDate(_ date: Date, healthStore: HKHealthStore) async throws -> Int {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let startOfDay = Calendar.current.startOfDay(for: date)
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let predicate = HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: endOfDay,
        options: .strictStartDate
    )
    
    return try await withCheckedThrowingContinuation { continuation in
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            if let error = error {
                continuation.resume(throwing: error)
                return
            }
            
            let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            continuation.resume(returning: Int(steps))
        }
        
        healthStore.execute(query)
    }
}

struct DailySteps: Equatable, Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
}

enum HealthUpdate {
    case stepsUpdated
    case heartRateUpdated
}

extension DependencyValues {
    var healthKitClient: HealthKitClient {
        get { self[HealthKitClient.self] }
        set { self[HealthKitClient.self] = newValue }
    }
}
