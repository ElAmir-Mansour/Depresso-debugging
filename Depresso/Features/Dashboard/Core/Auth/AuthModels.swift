// In Core/Auth/AuthModels.swift
import Foundation

// MARK: - User Model (Defined ONLY here)
struct User: Codable, Equatable, Sendable {
    let id: String
    let email: String
    let createdAt: Date
    let hasGrantedResearchConsent: Bool
    let researchParticipantId: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
        case hasGrantedResearchConsent = "has_granted_research_consent"
        case researchParticipantId = "research_participant_id"
    }
}

// MARK: - Request Models
struct RegisterRequest: Codable, Sendable {
    let email: String
    let password: String
    let confirmPassword: String
    enum CodingKeys: String, CodingKey { case email, password, confirmPassword = "confirm_password" }
}
struct LoginRequest: Codable, Sendable {
    let email: String
    let password: String
}
struct RefreshTokenRequest: Codable, Sendable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
}
struct ResearchConsentRequest: Codable, Sendable {
    let consents: Bool
    let consentVersion: String
    enum CodingKeys: String, CodingKey { case consents, consentVersion = "consent_version" }
}

// MARK: - Response Models
struct AuthResponse: Codable, Equatable, Sendable {
    let user: User
    let accessToken: String
    let refreshToken: String
    enum CodingKeys: String, CodingKey { case user, accessToken = "access_token", refreshToken = "refresh_token" }
}
struct ResearchConsentResponse: Codable, Equatable, Sendable {
    let success: Bool
    let researchParticipantId: String?
    let grantedAt: Date?
    enum CodingKeys: String, CodingKey { case success, researchParticipantId = "research_participant_id", grantedAt = "granted_at" }
    
}

// MARK: - API Error Model
struct APIError: Codable, Error, Equatable {
    let code: String
    let message: String
}

// MARK: - Auth Errors
enum AuthError: LocalizedError, Equatable {
    case invalidURL, invalidResponse, notAuthenticated, tokenExpired, httpError(Int), serverError(String), keychainError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .invalidResponse: return "Invalid response from server"
        case .notAuthenticated: return "Not authenticated. Please log in."
        case .tokenExpired: return "Session expired. Please log in again."
        case .httpError(let code): return "Server error: \(code)"
        case .serverError(let message): return message
        case .keychainError(let message): return "Security error: \(message)"
        }
    }
}


extension AuthResponse {
    // **FIX:** Define 'mock' for AuthResponse, provide unique tokens
     static var mock: AuthResponse { // Use computed property
         AuthResponse(
            user: User.mock, // Use User.mock here
            accessToken: "mock_access_\(UUID().uuidString)",
            refreshToken: "mock_refresh_\(UUID().uuidString)"
        )
     }
}

extension ResearchConsentResponse {
    // **FIX:** Define 'mock' for ResearchConsentResponse
    static func mock(granted: Bool) -> ResearchConsentResponse {
         ResearchConsentResponse(
            success: true, researchParticipantId: granted ? "mock_research_\(UUID().uuidString)" : nil,
            grantedAt: granted ? Date() : nil
         )
     }
}
