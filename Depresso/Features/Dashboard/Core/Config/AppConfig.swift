// In Core/Config/AppConfig.swift
import Foundation

enum AppEnvironment {
    case development // Running in Xcode, Debug build
    case staging     // Internal testing build (e.g., TestFlight)
    case production  // App Store release
}

struct AppConfig {
    // Determine the current environment based on build configuration
    static let current: AppEnvironment = {
        #if DEBUG // Typically used for development builds in Xcode
        return .development
        #elseif STAGING // Requires a STAGING flag in Staging build config (e.g., OTHER_SWIFT_FLAGS = "-DSTAGING")
        return .staging
        #else // Default to production for Release builds
        return .production
        #endif
    }()

    // Define API base URLs for each environment
    static var apiBaseURL: String {
        switch current {
        case .development:
            // Use localhost or a specific dev server
            // Ensure your local backend is running on this address/port
            return "http://localhost:3000/api/v1" // Example for a local Node.js backend
        case .staging:
            // Use your staging server URL
            return "https://staging-api.depresso.app/api/v1" // Replace with your actual staging URL
        case .production:
            // Use your production server URL
            return "https://api.depresso.app/api/v1" // Replace with your actual production URL
        }
    }

    // Flag to easily switch between real network calls and simulated responses during development
    static var useSimulatedBackend: Bool {
        // Return true only when in development environment *and* you want to simulate
        #if DEBUG
        // Set this to true to use simulated AuthClient/DataSubmissionClient,
        // false to hit your actual local/dev backend (http://localhost:3000/...)
        return true // CHANGE THIS TO `false` TO TEST YOUR ACTUAL BACKEND
        #else
        // Always use the real backend for Staging and Production
        return false
        #endif
    }

    // You can add other configurations here, e.g.:
    // static var featureFlags: [String: Bool] = [...]
    // static var loggingLevel: LogLevel = .info
}
