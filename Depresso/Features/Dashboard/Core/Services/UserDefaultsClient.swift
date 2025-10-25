//
//  UserDefaultsClient.swift
//  Depresso
//
//  Created by ElAmir Mansour on 25/10/2025.
//

import Foundation
import ComposableArchitecture

@DependencyClient
struct UserDefaultsClient: Sendable {
    var saveOnboardingDate: @Sendable (Date) async throws -> Void
    var getOnboardingDate: @Sendable () async throws -> Date?
    var savePHQ8Score: @Sendable (Int) async throws -> Void
    var getLastPHQ8Score: @Sendable () async throws -> Int?
}

extension UserDefaultsClient: DependencyKey {
    static let liveValue = Self(
        saveOnboardingDate: { date in
            UserDefaults.standard.set(date, forKey: "onboardingDate")
        },
        getOnboardingDate: {
            UserDefaults.standard.object(forKey: "onboardingDate") as? Date
        },
        savePHQ8Score: { score in
            UserDefaults.standard.set(score, forKey: "lastPHQ8Score")
            UserDefaults.standard.set(Date(), forKey: "lastPHQ8Date")
        },
        getLastPHQ8Score: {
            let score = UserDefaults.standard.integer(forKey: "lastPHQ8Score")
            return score > 0 ? score : nil
        }
    )
    
    static let previewValue = Self(
        saveOnboardingDate: { _ in },
        getOnboardingDate: { Date().addingTimeInterval(-30 * 24 * 60 * 60) },
        savePHQ8Score: { _ in },
        getLastPHQ8Score: { 12 }
    )
    
    static let testValue = Self()
}

extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
