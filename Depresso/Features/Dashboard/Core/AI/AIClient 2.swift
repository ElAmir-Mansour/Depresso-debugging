//
//  AIClient 2.swift
//  Depresso
//
//  Created by ElAmir Mansour on 03/10/2025.
//


// In Core/AI/AIClient.swift
import Foundation
import ComposableArchitecture
import FirebaseAI

// 1. Define the interface (the "protocol") for our dependency.
// This describes what the dependency can do, but not how it does it.
struct AIClient {
    var generateResponse: (_ prompt: String) async throws -> String
}

// 2. Extend the client to conform to DependencyKey, which allows it
// to be registered as a dependency with TCA.
extension AIClient: DependencyKey {
    // The "live" implementation that will be used when the app runs on a device.
    static let liveValue = Self(
        generateResponse: { prompt in
            // Initialize the Firebase AI service
            let ai = FirebaseAI.firebaseAI(backend:.googleAI())
            let model = ai.generativeModel(modelName: "gemini-1.5-flash")

            // Call the Gemini API
            let response = try await model.generateContent(prompt)

            // Process the response
            guard let text = response.text else {
                throw AIError.responseError
            }

            return text
        }
    )
}

// 3. Expose the dependency to the TCA system so we can use it in our reducers.
extension DependencyValues {
    var aiClient: AIClient {
        get { self[AIClient.self] }
        set { self[AIClient.self] = newValue }
    }
}

// A custom error to make error handling clearer.
enum AIError: Error {
    case responseError
}
