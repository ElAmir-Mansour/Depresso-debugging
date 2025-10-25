// In Core/Storage/UserDefaultsClient.swift
import Foundation
import ComposableArchitecture

// MARK: - UserDefaults Keys
private enum UserDefaultsKeys {
    static let onboardingDate = "onboardingDate"
    static let lastPHQ8Score = "lastPHQ8Score"
    static let lastPHQ8Date = "lastPHQ8Date"
    static let likedPostIDs = "likedPostIDs"
}

// Client to manage app-level user defaults (not sensitive data)
@DependencyClient
struct UserDefaultsClient {
    // Onboarding & Assessment
    var saveOnboardingDate: @Sendable (Date) async -> Void
    var getOnboardingDate: @Sendable () async -> Date?
    var savePHQ8Score: @Sendable (Int, Date) async -> Void
    var getLastPHQ8Score: @Sendable () async -> Int?
    var getLastPHQ8Date: @Sendable () async -> Date?

    // Liked Posts
    // Inside UserDefaultsClient
    var loadLikedPostIDs: @Sendable () -> Set<UUID> = { [] } // Add a default value
    var saveLikedPostIDs: @Sendable (Set<UUID>) async -> Void
}

// **FIX:** Conform to both DependencyKey AND TestDependencyKey
extension UserDefaultsClient: DependencyKey, TestDependencyKey {
    static let liveValue = UserDefaultsClient(
        // Onboarding & Assessment
        saveOnboardingDate: { date in
            Task.detached {
                UserDefaults.standard.set(date, forKey: UserDefaultsKeys.onboardingDate)
                print(" MOCK Saved Onboarding Date: \(date)")
            }
        },
        getOnboardingDate: {
            UserDefaults.standard.object(forKey: UserDefaultsKeys.onboardingDate) as? Date
        },
        savePHQ8Score: { score, date in
            Task.detached {
                UserDefaults.standard.set(score, forKey: UserDefaultsKeys.lastPHQ8Score)
                UserDefaults.standard.set(date, forKey: UserDefaultsKeys.lastPHQ8Date)
                print(" MOCK Saved PHQ8 Score: \(score) on \(date)")
            }
        },
        getLastPHQ8Score: {
            UserDefaults.standard.object(forKey: UserDefaultsKeys.lastPHQ8Score) as? Int
        },
        getLastPHQ8Date: {
             UserDefaults.standard.object(forKey: UserDefaultsKeys.lastPHQ8Date) as? Date
         },

        // Liked Posts
        loadLikedPostIDs: {
            let ids: Set<UUID>
            if let uuidStrings = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.likedPostIDs) {
                ids = Set(uuidStrings.compactMap { UUID(uuidString: $0) })
            } else {
                ids = []
            }
            return ids
        },
        saveLikedPostIDs: { ids in
            Task.detached {
                let uuidStrings = ids.map { $0.uuidString }
                UserDefaults.standard.set(uuidStrings, forKey: UserDefaultsKeys.likedPostIDs)
            }
        }
    )

    // **FIX:** Define testValue (required by TestDependencyKey)
    static let testValue = UserDefaultsClient(
         saveOnboardingDate: { _ in print(" MOCK [TEST] Save Onboarding Date") },
         getOnboardingDate: {
             print(" MOCK [TEST] Get Onboarding Date")
             return Calendar.current.date(byAdding: .day, value: -10, to: Date()) // Example
         },
         savePHQ8Score: { score, date in print(" MOCK [TEST] Save PHQ8 Score: \(score) on \(date)") },
         getLastPHQ8Score: {
             print(" MOCK [TEST] Get PHQ8 Score")
             return 12 // Example
         },
         getLastPHQ8Date: {
             print(" MOCK [TEST] Get PHQ8 Date")
             return Calendar.current.date(byAdding: .day, value: -1, to: Date()) // Example
         },
         loadLikedPostIDs: {
             print(" MOCK [TEST] Load Liked IDs")
             return Set()
         },
         saveLikedPostIDs: { _ in print(" MOCK [TEST] Save Liked IDs") }
     )
    // Preview value can reuse testValue or liveValue (if simulating)
    static let previewValue = testValue // Use testValue for previews
}


extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
        // **FIX:** Ensure subscript uses the correct type
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
