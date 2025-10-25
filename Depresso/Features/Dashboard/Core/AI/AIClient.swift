// In Core/AI/AIClient.swift (Final Refactor for Huawei Competition API)
import Foundation
import ComposableArchitecture
import FirebaseAI // Required to understand ModelContent and Part types

// --- API Data Structures (from the PDF guide) ---
struct HuaweiMessage: Codable {
    let role: String
    let content: String
}

struct HuaweiChatRequest: Codable {
    let model: String
    let messages: [HuaweiMessage]
}

struct HuaweiChoice: Codable {
    let message: HuaweiMessage
}

struct HuaweiChatResponse: Codable {
    let choices: [HuaweiChoice]
}
// --- End of API Data Structures ---


struct AIClient {
    var generateResponse: (_ history: [ModelContent], _ prompt: String, _ systemPrompt: String?) async throws -> String
}

extension AIClient: DependencyKey {
    static let liveValue: Self = {
        // ✅ FIX: Explicitly define the closure to resolve the ambiguity for the compiler.
        let generateResponse: @Sendable (_ history: [ModelContent], _ prompt: String, _ systemPrompt: String?) async throws -> String = { history, prompt, systemPrompt in
            guard let url = URL(string: HuaweiCredentials.endpointURL) else {
                throw AIError.invalidURL
            }
            let modelName = HuaweiCredentials.modelName

            var apiMessages: [HuaweiMessage] = []

            if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
                apiMessages.append(HuaweiMessage(role: "system", content: systemPrompt))
            }

            history.forEach { message in
                let role = message.role == "model" ? "assistant" : "user"
                // ✅ FINAL FIX: The 'Part' is a String underneath, so we cast it directly.
                guard let content = message.parts.first as? String else { return }
                apiMessages.append(HuaweiMessage(role: role, content: content))
            }
            apiMessages.append(HuaweiMessage(role: "user", content: prompt))
            
            let requestBody = HuaweiChatRequest(model: modelName, messages: apiMessages)
            let requestData = try JSONEncoder().encode(requestBody)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = requestData
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(HuaweiCredentials.apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let errorDetails = String(data: data, encoding: .utf8) ?? "No details"
                print("API Error (Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)): \(errorDetails)")
                throw AIError.responseError
            }
            
            let apiResponse = try JSONDecoder().decode(HuaweiChatResponse.self, from: data)

            guard var reply = apiResponse.choices.first?.message.content else {
                throw AIError.responseError
            }
            
            if let thinkRange = reply.range(of: "</think>") {
                reply.removeSubrange(...thinkRange.upperBound)
            }

            return reply.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return Self(generateResponse: generateResponse)
    }()
}

extension DependencyValues {
    var aiClient: AIClient {
        get { self[AIClient.self] }
        set { self[AIClient.self] = newValue }
    }
}

enum AIError: Error {
    case invalidURL
    case responseError
}
