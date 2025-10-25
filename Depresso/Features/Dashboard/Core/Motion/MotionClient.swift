// In Core/Motion/MotionClient.swift
import Foundation
import CoreMotion
import ComposableArchitecture

// ✅ ADD: Make CMAcceleration Equatable
extension CMAcceleration: @retroactive Equatable {
    public static func == (lhs: CMAcceleration, rhs: CMAcceleration) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
}

struct MotionData: Equatable {
    var userAcceleration: CMAcceleration
}

struct MotionClient {
    var start: () -> AsyncStream<MotionData>
}

extension MotionClient: DependencyKey {
    static let liveValue: Self = {
        let motionManager = CMMotionManager()

        return Self(
            start: {
                AsyncStream { continuation in
                    guard motionManager.isDeviceMotionAvailable else {
                        continuation.finish()
                        return
                    }

                    motionManager.deviceMotionUpdateInterval = 0.5

                    motionManager.startDeviceMotionUpdates(to: .main) { data, error in
                        guard let data = data, error == nil else {
                            continuation.finish()
                            return
                        }
                        continuation.yield(MotionData(userAcceleration: data.userAcceleration))
                    }

                    continuation.onTermination = { @Sendable _ in
                        motionManager.stopDeviceMotionUpdates()
                    }
                }
            }
        )
    }()
}

extension DependencyValues {
    var motionClient: MotionClient {
        get { self[MotionClient.self] }
        set { self[MotionClient.self] = newValue }
    }
}
