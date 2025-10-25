//
//  SwiftDataClient.swift
//  Depresso
//
//  Created by ElAmir Mansour on 26/10/2025.
//

// Depresso/Core/Clients/SwiftDataClient.swift

import ComposableArchitecture
import SwiftData
import Foundation

struct SwiftDataClient {
    var fetchMessages: @Sendable () async throws -> [ChatMessage]
    var saveMessage: @Sendable (String, Bool, TypingMetrics?, MotionMetrics?) async throws -> Void
    var fetchTasks: @Sendable () async throws -> [WellnessTask]
    var saveTask: @Sendable (String, Bool) async throws -> Void
    var updateTask: @Sendable (UUID, Bool) async throws -> Void
    var deleteTask: @Sendable (UUID) async throws -> Void
    var fetchPosts: @Sendable () async throws -> [CommunityPost]
    var savePost: @Sendable (String, Data?) async throws -> Void
}

extension SwiftDataClient: DependencyKey {
    static let liveValue: SwiftDataClient = {
        // Access the shared ModelContainer
        let container = try! ModelContainer(
            for: ChatMessage.self, WellnessTask.self, CommunityPost.self
        )
        
        return SwiftDataClient(
            fetchMessages: {
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<ChatMessage>(
                    sortBy: [SortDescriptor(\.timestamp)]
                )
                return try context.fetch(descriptor)
            },
            saveMessage: { content, isUser, typing, motion in
                let context = ModelContext(container)
                let message = ChatMessage(
                    content: content,
                    isUser: isUser,
                    timestamp: .now
                )
                // Store metrics as JSON or separate fields
                context.insert(message)
                try context.save()
            },
            fetchTasks: {
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<WellnessTask>()
                return try context.fetch(descriptor)
            },
            saveTask: { title, isCompleted in
                let context = ModelContext(container)
                let task = WellnessTask(title: title, isCompleted: isCompleted)
                context.insert(task)
                try context.save()
            },
            updateTask: { id, isCompleted in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<WellnessTask>(
                    predicate: #Predicate { $0.id == id }
                )
                if let task = try context.fetch(descriptor).first {
                    task.isCompleted = isCompleted
                    try context.save()
                }
            },
            deleteTask: { id in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<WellnessTask>(
                    predicate: #Predicate { $0.id == id }
                )
                if let task = try context.fetch(descriptor).first {
                    context.delete(task)
                    try context.save()
                }
            },
            fetchPosts: {
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<CommunityPost>(
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
                return try context.fetch(descriptor)
            },
            savePost: { content, imageData in
                let context = ModelContext(container)
                let post = CommunityPost(
                    content: content,
                    imageData: imageData,
                    timestamp: .now
                )
                context.insert(post)
                try context.save()
            }
        )
    }()
    
    static let testValue = SwiftDataClient(
        fetchMessages: { [] },
        saveMessage: { _, _, _, _ in },
        fetchTasks: { [] },
        saveTask: { _, _ in },
        updateTask: { _, _ in },
        deleteTask: { _ in },
        fetchPosts: { [] },
        savePost: { _, _ in }
    )
}

extension DependencyValues {
    var swiftDataClient: SwiftDataClient {
        get { self[SwiftDataClient.self] }
        set { self[SwiftDataClient.self] = newValue }
    }
}
