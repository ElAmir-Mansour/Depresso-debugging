import Foundation
import ComposableArchitecture

// MARK: - Behavioral Data Models
struct BehavioralDataSubmission: Codable, Equatable {
    let sessionId: UUID
    let timestamp: Date

    // Typing Metrics
    let wordsPerMinute: Double
    let totalEdits: Int
    let editRate: Double // Note: Ensure you calculate this (e.g., totalEdits / durationSeconds)

    // Motion Metrics
    let avgAcceleration: Double // Note: Ensure you calculate this (magnitude of average X, Y, Z)
    let accelerationVariance: Double?
    let motionSamples: Int

    // Session Metrics
    let durationSeconds: Double
    let journalEntryLength: Int

    // Context
    let phq8Score: Int?
    let timeOfDay: String
    let daysSinceOnboarding: Int?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case timestamp
        case wordsPerMinute = "words_per_minute"
        case totalEdits = "total_edits"
        case editRate = "edit_rate"
        case avgAcceleration = "avg_acceleration"
        case accelerationVariance = "acceleration_variance"
        case motionSamples = "motion_samples"
        case durationSeconds = "duration_seconds"
        case journalEntryLength = "journal_entry_length"
        case phq8Score = "phq8_score"
        case timeOfDay = "time_of_day"
        case daysSinceOnboarding = "days_since_onboarding"
    }
}

struct DataSubmissionResponse: Codable {
    let success: Bool
    let submissionId: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case success
        case submissionId = "submission_id"
        case timestamp
    }
}

// MARK: - Data Submission Client
@DependencyClient
struct DataSubmissionClient {
    var submitBehavioralData: @Sendable (BehavioralDataSubmission) async throws -> DataSubmissionResponse
    var checkSubmissionStatus: @Sendable (String) async throws -> Bool
    // Note: You had submitMetrics in AICompanionJournalFeature, but the client defines submitBehavioralData.
    // I'm assuming submitBehavioralData is the correct one to implement based on this file and your snippet.
}

// MARK: - Dependency Key
extension DataSubmissionClient: DependencyKey {
    static let liveValue: DataSubmissionClient = {
        // Use AppConfig for the base URL
        let apiBaseURL = AppConfig.apiBaseURL // Changed from hardcoded URL

        // Use simulated backend during development if configured
        if AppConfig.useSimulatedBackend {
            return Self.previewValue // Use previewValue as the simulated implementation
        }

        // Real implementation
        return DataSubmissionClient(
            submitBehavioralData: { submission in
                // Get access token from Keychain
                guard let accessToken = try KeychainManager.shared.retrieve(for: .accessToken) else {
                    throw DataSubmissionError.notAuthenticated
                }

                // Check if user has granted research consent
                // NOTE: Fetching the current user here might be inefficient if done frequently.
                // Consider passing consent status or fetching it earlier in the flow.
                 guard let user = try? await AuthClient.liveValue.getCurrentUser(),
                       user.hasGrantedResearchConsent == true else {
                     throw DataSubmissionError.consentNotGranted
                 }

                // Prepare request
                guard let url = URL(string: "\(apiBaseURL)/behavioral-data") else {
                    throw DataSubmissionError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

                // Add research consent header for backend validation
                request.setValue("true", forHTTPHeaderField: "X-Research-Consent")

                // Encode submission
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601 // Ensure dates are ISO8601 formatted
                request.httpBody = try encoder.encode(submission)

                // Perform request
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw DataSubmissionError.invalidResponse
                }

                // Handle specific error codes
                switch httpResponse.statusCode {
                case 200...299:
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(DataSubmissionResponse.self, from: data)

                case 401:
                    // Token expired - the TokenRefreshMiddleware should handle this
                    throw DataSubmissionError.tokenExpired

                case 403:
                    // User doesn't have research consent OR other permission issue
                    // Check backend error message if available
                    if let apiError = try? JSONDecoder().decode(APIError.self, from: data),
                       apiError.code == "CONSENT_REQUIRED" { // Example error code check
                         throw DataSubmissionError.consentNotGranted
                    }
                    throw DataSubmissionError.httpError(httpResponse.statusCode) // General forbidden

                case 429:
                    // Rate limited
                    throw DataSubmissionError.rateLimited

                default:
                    // Try to decode a backend error message
                    if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                        throw DataSubmissionError.serverError(apiError.message)
                    }
                    // Fallback generic HTTP error
                    throw DataSubmissionError.httpError(httpResponse.statusCode)
                }
            },
            checkSubmissionStatus: { submissionId in
                guard let accessToken = try KeychainManager.shared.retrieve(for: .accessToken) else {
                    throw DataSubmissionError.notAuthenticated
                }

                guard let url = URL(string: "\(apiBaseURL)/behavioral-data/\(submissionId)") else {
                    throw DataSubmissionError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                     // Or throw DataSubmissionError.invalidResponse
                     return false
                }

                switch httpResponse.statusCode {
                 case 200: // Found
                     // Assuming backend returns {"exists": true} or similar
                     let decoder = JSONDecoder()
                     let statusResponse = try? decoder.decode([String: Bool].self, from: data)
                     return statusResponse?["exists"] ?? false
                 case 404: // Not Found
                     return false
                 case 401:
                     throw DataSubmissionError.tokenExpired
                 default:
                     // Or throw specific error based on code
                     return false
                 }
            }
        )
    }()

    // Preview/Test value - prints to console
    static let previewValue = DataSubmissionClient(
        submitBehavioralData: { submission in
            print(" MOCK [PREVIEW] Behavioral Data Submission:")
            // Basic printout for preview/simulation
            print("   Session ID: \(submission.sessionId)")
            print("   Timestamp: \(submission.timestamp)")
            print("   WPM: \(submission.wordsPerMinute), Edits: \(submission.totalEdits)")
            print("   Duration: \(submission.durationSeconds)s, Length: \(submission.journalEntryLength)")
            print("   PHQ-8: \(submission.phq8Score ?? -1), Time: \(submission.timeOfDay)")
            print("   Days Since Onboarding: \(submission.daysSinceOnboarding ?? -1)")
            try await Task.sleep(for: .seconds(1)) // Simulate network delay
            return DataSubmissionResponse(
                success: true,
                submissionId: "simulated_\(UUID().uuidString)",
                timestamp: Date()
            )
        },
        checkSubmissionStatus: { submissionId in
            print(" MOCK [PREVIEW] Check Submission Status: \(submissionId)")
            try await Task.sleep(for: .milliseconds(300))
            return true // Assume exists in preview
        }
    )
}

// MARK: - Dependency Values Extension
extension DependencyValues {
    var dataSubmissionClient: DataSubmissionClient {
        get { self[DataSubmissionClient.self] }
        set { self[DataSubmissionClient.self] = newValue }
    }
}

// MARK: - Errors
enum DataSubmissionError: LocalizedError, Equatable {
    case notAuthenticated
    case consentNotGranted
    case tokenExpired
    case rateLimited
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        case .consentNotGranted:
            return "Research consent not granted. Please grant consent in Settings to contribute data."
        case .tokenExpired:
            return "Session expired. Please log in again." // Or "Attempting to refresh session..."
        case .rateLimited:
            return "Too many submissions. Please try again later."
        case .invalidURL:
            return "Invalid server URL configured." // More specific error
        case .invalidResponse:
            return "Received an invalid response from the server." // More specific error
        case .httpError(let code):
            return "Server returned an error (Code: \(code))." // More specific error
        case .serverError(let message):
            return message // Display backend-provided message
        }
    }
}


// MARK: - Helper Functions (Added from Snippet)
extension DataSubmissionClient {
    // Helper to determine time of day
    static func getTimeOfDay(from date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5..<12:
            return "morning"
        case 12..<17:
            return "afternoon"
        case 17..<21:
            return "evening"
        default:
            return "night"
        }
    }

    // Helper to calculate days since onboarding
    static func daysSinceOnboarding(from onboardingDate: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: onboardingDate, to: Date())
        return days.day ?? 0
    }
}
