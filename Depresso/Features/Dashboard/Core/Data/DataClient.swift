// In Core/Data/DataClient.swift
import Foundation
import SwiftData
import ComposableArchitecture

// MARK: - Wrapper to safely inject ModelContext
/// Swift 6 forbids ModelContext from being Sendable.
/// We wrap it in a box so it can live inside TCA's DependencyValues.
final class ModelContextBox: @unchecked Sendable {
    let context: ModelContext
    init(_ context: ModelContext) {
        self.context = context
    }
}

// MARK: - DataClient definition
struct DataClient {
    var fetchTasks: () throws -> [WellnessTask]
    var addTask: (_ title: String) throws -> Void
    var toggleTask: (_ task: WellnessTask) throws -> Void
}

// MARK: - Dependency Key
extension DataClient: DependencyKey, TestDependencyKey {
    // This is the "live" implementation for your actual app
    static let liveValue: DataClient = {
        return DataClient(
            fetchTasks: {
                // Resolve the dependency here, inside the method closure
                @Dependency(\.modelContext) var modelContextBox
                
                let descriptor = FetchDescriptor<WellnessTask>(
                    sortBy: [SortDescriptor(\.creationDate)]
                )
                return try modelContextBox.context.fetch(descriptor)
            },
            addTask: { title in
                // Resolve the dependency here as well
                @Dependency(\.modelContext) var modelContextBox

                let newTask = WellnessTask(title: title)
                modelContextBox.context.insert(newTask)
                try modelContextBox.context.save()
            },
            toggleTask: { task in
                // And finally, resolve it here too
                @Dependency(\.modelContext) var modelContextBox

                let taskId = task.id
                let predicate = #Predicate<WellnessTask> { $0.id == taskId }
                
                var descriptor = FetchDescriptor(predicate: predicate)
                descriptor.fetchLimit = 1
                guard let taskToUpdate = try modelContextBox.context.fetch(descriptor).first else { return }
                taskToUpdate.isCompleted.toggle()
                try modelContextBox.context.save()
            }
        )
    }()
    
    // This is the mock implementation for your SwiftUI previews
    static let previewValue = Self(
        fetchTasks: {
            [
                WellnessTask(title: "Go for a 15-minute walk", isCompleted: true),
                WellnessTask(title: "Meditate for 5 minutes", isCompleted: false),
                WellnessTask(title: "Write in your journal", isCompleted: false)
            ]
        },
        addTask: { _ in print("AddTask tapped in preview") },
        toggleTask: { _ in print("ToggleTask tapped in preview") }
    )
}


// MARK: - Extend DependencyValues
extension DependencyValues {
    var dataClient: DataClient {
        get { self[DataClient.self] }
        set { self[DataClient.self] = newValue }
    }
}

// MARK: - ModelContext injection
private enum ModelContextKey: DependencyKey {
    static var liveValue: ModelContextBox {
        fatalError("ModelContext must be set at runtime with .withDependencies { }")
    }
}

extension DependencyValues {
    var modelContext: ModelContextBox {
        get { self[ModelContextKey.self] }
        set { self[ModelContextKey.self] = newValue }
    }
}
