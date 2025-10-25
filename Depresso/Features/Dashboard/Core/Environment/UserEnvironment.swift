//
//  UserEnvironment.swift
//  Depresso
//
//  Created by ElAmir Mansour on 25/10/2025.
//

import SwiftUI
import ComposableArchitecture

// Environment key for current user
private struct CurrentUserKey: EnvironmentKey {
    static let defaultValue: User? = nil
}

extension EnvironmentValues {
    var currentUser: User? {
        get { self[CurrentUserKey.self] }
        set { self[CurrentUserKey.self] = newValue }
    }
}

// Dependency key for current user in TCA
private enum CurrentUserDependencyKey: DependencyKey {
    static let liveValue: User? = nil
    static let testValue: User? = User(
        id: "test_user",
        email: "test@example.com",
        createdAt: Date(),
        hasGrantedResearchConsent: true,
        researchParticipantId: "test_research_id"
    )
}

extension DependencyValues {
    var currentUser: User? {
        get { self[CurrentUserDependencyKey.self] }
        set { self[CurrentUserDependencyKey.self] = newValue }
    }
}
