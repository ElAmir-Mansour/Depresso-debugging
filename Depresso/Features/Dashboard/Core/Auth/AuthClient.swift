// In Core/Auth/AuthClient.swift
import Foundation
import ComposableArchitecture

// MARK: - Auth Client Definition
@DependencyClient
struct AuthClient: Sendable {
    var register: @Sendable (RegisterRequest) async throws -> AuthResponse
    var login: @Sendable (LoginRequest) async throws -> AuthResponse
    var logout: @Sendable () async throws -> Void
    var refreshToken: @Sendable () async throws -> AuthResponse
    var grantResearchConsent: @Sendable (ResearchConsentRequest) async throws -> ResearchConsentResponse
    var revokeResearchConsent: @Sendable () async throws -> Void
    var getCurrentUser: @Sendable () async throws -> User? // Use User from AuthModels
    var isAuthenticated: @Sendable () -> Bool = { false } // Default added
}

// MARK: - Dependency Key Implementation
extension AuthClient: DependencyKey {

    // MARK: - Simulated Implementation (for DEBUG and Previews)
    static let simulatedValue = Self(
        register: { request in
             print(" MOCK Auth: Simulating Register..."); try await Task.sleep(for: .seconds(1));
             let user = User(id: "sim_\(UUID().uuidString)", email: request.email, createdAt: Date(), hasGrantedResearchConsent: false, researchParticipantId: nil)
             // **FIX:** Use AuthResponse.mock or create directly
             let response = AuthResponse(user: user, accessToken: "sim_access_\(UUID().uuidString)", refreshToken: "sim_refresh_\(UUID().uuidString)")
             Task.detached { try? KeychainManager.shared.save(response.accessToken, for: .accessToken) }
             Task.detached { try? KeychainManager.shared.save(response.refreshToken, for: .refreshToken) }
             Task.detached { try? KeychainManager.shared.save(user.id, for: .userId) }
             return response
        },
        login: { request in
              print(" MOCK Auth: Simulating Login..."); try await Task.sleep(for: .seconds(1));
             let userId = "sim_user_\(abs(request.email.hashValue))"; let hasConsent = true
             let user = User(id: userId, email: request.email, createdAt: Date().addingTimeInterval(-.random(in: 1...30) * 24 * 60 * 60), hasGrantedResearchConsent: hasConsent, researchParticipantId: hasConsent ? "sim_research_\(userId)" : nil)
             // **FIX:** Use AuthResponse.mock or create directly
             let response = AuthResponse(user: user, accessToken: "sim_access_\(UUID().uuidString)", refreshToken: "sim_refresh_\(UUID().uuidString)")
             Task.detached { try? KeychainManager.shared.save(response.accessToken, for: .accessToken) }
             Task.detached { try? KeychainManager.shared.save(response.refreshToken, for: .refreshToken) }
             Task.detached { try? KeychainManager.shared.save(user.id, for: .userId) }
             return response
        },
         logout: { print(" MOCK Auth: Simulating Logout."); try? KeychainManager.shared.clearAll() },
          refreshToken: {
               print(" MOCK Auth: Simulating Refresh..."); try await Task.sleep(for: .seconds(0.5));
              guard let userId = try? KeychainManager.shared.retrieve(for: .userId) else { throw AuthError.notAuthenticated }
              // **FIX:** Construct user directly, don't call self.getCurrentUser
               let refreshedUser = User(id: userId, email: "simulated@user.com", createdAt: Date().addingTimeInterval(-10*24*60*60), hasGrantedResearchConsent: true, researchParticipantId: "sim_research_\(userId)")
              // **FIX:** Use AuthResponse.mock or create directly
               let response = AuthResponse(user: refreshedUser, accessToken: "sim_refreshed_access_\(UUID().uuidString)", refreshToken: "sim_refreshed_refresh_\(UUID().uuidString)")
              Task.detached { try? KeychainManager.shared.save(response.accessToken, for: .accessToken) }
              Task.detached { try? KeychainManager.shared.save(response.refreshToken, for: .refreshToken) }
              return response
          },
          grantResearchConsent: { request in
              print(" MOCK Auth: Simulating Grant Consent..."); try await Task.sleep(for: .seconds(1));
              // **FIX:** Use ResearchConsentResponse.mock or create directly
              return ResearchConsentResponse.mock(granted: true) // Use mock helper
          },
          revokeResearchConsent: { print(" MOCK Auth: Simulating Revoke Consent..."); try await Task.sleep(for: .seconds(0.5)); },
          getCurrentUser: {
               print(" MOCK Auth: Simulating Get User...");
               // **FIX:** Use User from AuthModels
              guard let userId = try? KeychainManager.shared.retrieve(for: .userId), let _ = try? KeychainManager.shared.retrieve(for: .accessToken) else { return nil }
              let hasConsent = true;
               // **FIX:** Use User from AuthModels
              return User(id: userId, email: "simulated@user.com", createdAt: Date().addingTimeInterval(-10*24*60*60), hasGrantedResearchConsent: hasConsent, researchParticipantId: hasConsent ? "sim_research_\(userId)" : nil)
          },
          isAuthenticated: { (try? KeychainManager.shared.retrieve(for: .accessToken)) != nil }
    )

    // Live value chooses implementation based on AppConfig
    static let liveValue: AuthClient = AppConfig.useSimulatedBackend ? simulatedValue : liveNetworkValue

    // **FIX:** Use Mocks from AuthModels.swift
    static let testValue = Self(
        register: { _ in AuthResponse.mock }, // Use AuthResponse.mock
        login: { _ in AuthResponse.mock },    // Use AuthResponse.mock
        logout: { },
        refreshToken: { AuthResponse.mock }, // Use AuthResponse.mock
        grantResearchConsent: { _ in ResearchConsentResponse.mock(granted: true) }, // Use helper
        revokeResearchConsent: { },
        getCurrentUser: { User.mock },          // Use User.mock
        isAuthenticated: { true }
    )

    static let previewValue = simulatedValue
}

// MARK: - Live Network Implementation
extension AuthClient {
    static let liveNetworkValue = Self(
        register: { requestData in
             let url = URL(string: "\(AppConfig.apiBaseURL)/auth/register")!; var request = URLRequest(url: url)
             request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
             request.httpBody = try JSONEncoder().encode(requestData); let (data, response) = try await URLSession.shared.data(for: request)
             guard let httpResponse = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
             switch httpResponse.statusCode {
                 case 200...299:
                      let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; let authResponse = try decoder.decode(AuthResponse.self, from: data)
                      try KeychainManager.shared.save(authResponse.accessToken, for: .accessToken); try KeychainManager.shared.save(authResponse.refreshToken, for: .refreshToken); try KeychainManager.shared.save(authResponse.user.id, for: .userId)
                      return authResponse
                 case 400...499: if let apiError = try? JSONDecoder().decode(APIError.self, from: data) { throw AuthError.serverError(apiError.message) }; throw AuthError.httpError(httpResponse.statusCode)
                 default: throw AuthError.httpError(httpResponse.statusCode)
              }
        },
        login: { requestData in
             let url = URL(string: "\(AppConfig.apiBaseURL)/auth/login")!; var request = URLRequest(url: url)
             request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
             request.httpBody = try JSONEncoder().encode(requestData); let (data, response) = try await URLSession.shared.data(for: request)
             guard let httpResponse = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
             switch httpResponse.statusCode {
                 case 200...299:
                      let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; let authResponse = try decoder.decode(AuthResponse.self, from: data)
                      try KeychainManager.shared.save(authResponse.accessToken, for: .accessToken); try KeychainManager.shared.save(authResponse.refreshToken, for: .refreshToken); try KeychainManager.shared.save(authResponse.user.id, for: .userId)
                      return authResponse
                  case 401: throw AuthError.notAuthenticated
                  case 400...499: if let apiError = try? JSONDecoder().decode(APIError.self, from: data) { throw AuthError.serverError(apiError.message) }; throw AuthError.httpError(httpResponse.statusCode)
                  default: throw AuthError.httpError(httpResponse.statusCode)
              }
        },
        logout: { try KeychainManager.shared.clearAll() /* + optional backend call */ },
        refreshToken: {
             guard let refreshToken = try KeychainManager.shared.retrieve(for: .refreshToken) else { throw AuthError.notAuthenticated }
             let url = URL(string: "\(AppConfig.apiBaseURL)/auth/refresh")!; var request = URLRequest(url: url)
             request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
             request.httpBody = try JSONEncoder().encode(RefreshTokenRequest(refreshToken: refreshToken)); let (data, response) = try await URLSession.shared.data(for: request)
             guard let httpResponse = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
              switch httpResponse.statusCode {
                  case 200...299:
                       let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; let authResponse = try decoder.decode(AuthResponse.self, from: data)
                       try KeychainManager.shared.save(authResponse.accessToken, for: .accessToken); try KeychainManager.shared.save(authResponse.refreshToken, for: .refreshToken); try KeychainManager.shared.save(authResponse.user.id, for: .userId)
                       return authResponse
                   case 401: try KeychainManager.shared.clearAll(); throw AuthError.tokenExpired
                   default: throw AuthError.httpError(httpResponse.statusCode)
               }
        },
        grantResearchConsent: { requestData in
              guard let accessToken = try KeychainManager.shared.retrieve(for: .accessToken) else { throw AuthError.notAuthenticated }
              let url = URL(string: "\(AppConfig.apiBaseURL)/user/consent")!; var request = URLRequest(url: url)
              request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
              request.httpBody = try JSONEncoder().encode(requestData); let (data, response) = try await URLSession.shared.data(for: request)
              guard let httpResponse = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
              switch httpResponse.statusCode {
                   case 200...299: let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return try decoder.decode(ResearchConsentResponse.self, from: data)
                   case 401: throw AuthError.tokenExpired
                   default: throw AuthError.httpError(httpResponse.statusCode)
                }
        },
        revokeResearchConsent: {
             guard let accessToken = try KeychainManager.shared.retrieve(for: .accessToken) else { throw AuthError.notAuthenticated }
             let url = URL(string: "\(AppConfig.apiBaseURL)/user/consent")!; var request = URLRequest(url: url)
             request.httpMethod = "DELETE"; request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
             let (_, response) = try await URLSession.shared.data(for: request); guard let httpResponse = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
             switch httpResponse.statusCode { case 200...299: return; case 401: throw AuthError.tokenExpired; default: throw AuthError.httpError(httpResponse.statusCode) }
        },
        getCurrentUser: {
             guard let accessToken = try? KeychainManager.shared.retrieve(for: .accessToken),
                   let userId = try? KeychainManager.shared.retrieve(for: .userId) else {
                   // **FIX:** Ensure nil is returned, not implicitly
                   return nil
             }
             do {
                  let url = URL(string: "\(AppConfig.apiBaseURL)/user/me")!; var request = URLRequest(url: url)
                  request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                  let (data, response) = try await URLSession.shared.data(for: request)
                  guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                       if (response as? HTTPURLResponse)?.statusCode == 401 { /* Log */ }
                       try? KeychainManager.shared.clearAll(); return nil
                  }
                  let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
                  let user = try decoder.decode(User.self, from: data)
                  guard user.id == userId else { try? KeychainManager.shared.clearAll(); return nil }
                  return user
             } catch { /* Log */ return nil }
        },
        isAuthenticated: { (try? KeychainManager.shared.retrieve(for: .accessToken)) != nil }
    )
}


// MARK: - Dependency Values Convenience Accessor
extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
