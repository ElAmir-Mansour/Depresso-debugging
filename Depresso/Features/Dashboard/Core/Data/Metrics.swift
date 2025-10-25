// In Core/Data/Metrics.swift
import Foundation

// These structs define the data we collect for your research.
// Placing them here makes them accessible to any feature that needs them.

struct DailyMetrics: Equatable {
    let steps: Double
    let activeEnergy: Double
    let heartRate: Double
}

struct DeviceMotionMetrics: Equatable {
    let avgAccelerationX: Double
    let avgAccelerationY: Double
    let avgAccelerationZ: Double
}

struct TypingMetrics: Equatable {
    let wordsPerMinute: Double
    let totalEditCount: Int
}
