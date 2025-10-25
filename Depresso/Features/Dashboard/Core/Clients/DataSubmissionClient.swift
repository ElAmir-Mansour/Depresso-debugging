// Depresso/Core/Clients/DataSubmissionClient.swift

import ComposableArchitecture
import Foundation

struct DataSubmissionClient {
    var submitBehavioralData: @Sendable (BehavioralDataPayload) async throws -> Void
    var submitPHQ8Results: @Sendable (PHQ8Results) async throws -> Void
}

extension DataSubmissionClient: DependencyKey {
    static let liveValue: DataSubmissionClient = {
        // Replace with your actual backend URL
        let baseURL = URL(string: "https://your-backend-api.com/api")!
        
        return DataSubmissionClient(
            submitBehavioralData: { payload in
                var request = URLRequest(url: baseURL.appendingPathComponent("/behavioral-data"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                request.httpBody = try encoder.encode(payload)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw DataSubmissionError.serverError
                }
            },
            submitPHQ8Results: { results in
                var request = URLRequest(url: baseURL.appendingPathComponent("/phq8-results"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                request.httpBody = try encoder.encode(results)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw DataSubmissionError.serverError
                }
            }
        )
    }()
    
    static let testValue = DataSubmissionClient(
        submitBehavioralData: { payload in
            print("📤 [TEST] Submitting behavioral data: \(payload)")
        },
        submitPHQ8Results: { results in
            print("📤 [TEST] Submitting PHQ-8 results: \(results)")
        }
    )
}

// Helper function to get auth token
private func getAuthToken() -> String {
    // Implement your authentication logic
    // Could use Keychain, UserDefaults, or auth service
    return "your-auth-token"
}

struct BehavioralDataPayload: Codable, Equatable {
    let userId: String
    let sessionId: UUID
    let timestamp: Date
    let sessionDuration: TimeInterval
    let messageCount: Int
    let typingMetrics: AggregatedTypingMetrics?
    let motionMetrics: AggregatedMotionMetrics?
    let deviceInfo: DeviceInfo
}

struct AggregatedTypingMetrics: Codable, Equatable {
    let avgWPM: Double
    let avgEditCount: Double
    let totalTypingDuration: TimeInterval
    let messageCount: Int
}

struct AggregatedMotionMetrics: Codable, Equatable {
    let avgAcceleration: Double
    let totalSamples: Int
    let sessionCount: Int
}

struct DeviceInfo: Codable, Equatable {
    let model: String
    let osVersion: String
    let appVersion: String
    
    static var current: DeviceInfo {
        DeviceInfo(
            model: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }
}

struct PHQ8Results: Codable, Equatable {
    let userId: String
    let timestamp: Date
    let responses: [Int]
    let totalScore: Int
    let severity: String
}

enum DataSubmissionError: Error {
    case serverError
    case networkError
    case invalidResponse
}

extension DependencyValues {
    var dataSubmissionClient: DataSubmissionClient {
        get { self[DataSubmissionClient.self] }
        set { self[DataSubmissionClient.self] = newValue }
    }
}
