//
//  UserEnvironment.swift
//  Depresso
//
//  Created by ElAmir Mansour on 25/10/2025.
//

import SwiftUI

// Environment key to access current user anywhere in the app
private struct CurrentUserKey: EnvironmentKey {
    static let defaultValue: User? = nil
}

extension EnvironmentValues {
    var currentUser: User? {
        get { self[CurrentUserKey.self] }
        set { self[CurrentUserKey.self] = newValue }
    }
}

// Helper to access auth state in any view
extension View {
    func requiresAuth() -> some View {
        modifier(RequiresAuthModifier())
    }
}

struct RequiresAuthModifier: ViewModifier {
    @Environment(\.currentUser) var currentUser
    
    func body(content: Content) -> some View {
        if currentUser != nil {
            content
        } else {
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Authentication Required")
                    .font(.headline)
                Text("Please log in to access this feature")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
