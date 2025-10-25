// Depresso/Features/Dashboard/DashboardFeature.swift

import ComposableArchitecture
import Foundation

@Reducer
struct DashboardFeature {
    
    @ObservableState
    struct State: Equatable {
        var todaySteps: Int = 0
        var heartRate: Int = 0
        var activeEnergy: Int = 0
        var weeklySteps: [DailySteps] = []
        var isLoadingHealth: Bool = false
        var healthError: String?
        
        // Child feature state
        var tasks: TasksFeature.State = TasksFeature.State()
        
        // UI state
        var showAddTask: Bool = false
    }
    
    enum Action {
        case viewAppeared
        case refreshTapped
        
        // Health data actions
        case healthDataLoaded(HealthData)
        case healthDataFailed(String)
        
        // Child feature actions
        case tasks(TasksFeature.Action)
        
        // UI actions
        case addTaskButtonTapped
        case dismissAddTask
    }
    
    @Dependency(\.healthKitClient) var healthKitClient
    @Dependency(\.continuousClock) var clock
    
    var body: some ReducerOf<Self> {
        Scope(state: \.tasks, action: \.tasks) {
            TasksFeature()
        }
        
        Reduce { state, action in
            switch action {
                
            case .viewAppeared, .refreshTapped:
                state.isLoadingHealth = true
                state.healthError = nil
                
                return .run { send in
                    do {
                        // Request authorization first
                        try await healthKitClient.requestAuthorization()
                        
                        // Fetch all health data in parallel
                        async let steps = healthKitClient.fetchTodaySteps()
                        async let heartRate = healthKitClient.fetchHeartRate()
                        async let energy = healthKitClient.fetchActiveEnergy()
                        async let weeklySteps = healthKitClient.fetchWeeklySteps()
                        
                        let healthData = try await HealthData(
                            todaySteps: steps,
                            heartRate: heartRate,
                            activeEnergy: energy,
                            weeklySteps: weeklySteps
                        )
                        
                        await send(.healthDataLoaded(healthData))
                        
                    } catch {
                        await send(.healthDataFailed(error.localizedDescription))
                    }
                }
                
            case let .healthDataLoaded(data):
                state.todaySteps = data.todaySteps
                state.heartRate = data.heartRate
                state.activeEnergy = data.activeEnergy
                state.weeklySteps = data.weeklySteps
                state.isLoadingHealth = false
                return .none
                
            case let .healthDataFailed(error):
                state.healthError = error
                state.isLoadingHealth = false
                return .none
                
            case .addTaskButtonTapped:
                state.showAddTask = true
                return .none
                
            case .dismissAddTask:
                state.showAddTask = false
                return .none
                
            case .tasks:
                // Handle any delegate actions from child feature
                return .none
            }
        }
    }
}

struct HealthData: Equatable {
    let todaySteps: Int
    let heartRate: Int
    let activeEnergy: Int
    let weeklySteps: [DailySteps]
}

// MARK: - Tasks Child Feature

@Reducer
struct TasksFeature {
    
    @ObservableState
    struct State: Equatable {
        var tasks: [TaskValue] = []
        var isLoading: Bool = false
        var newTaskTitle: String = ""
    }
    
    struct TaskValue: Equatable, Identifiable {
        let id: UUID
        var title: String
        var isCompleted: Bool
        var createdAt: Date
    }
    
    enum Action {
        case viewAppeared
        case tasksLoaded([TaskValue])
        case taskToggled(UUID)
        case addTask(String)
        case deleteTask(UUID)
        case taskSaved
    }
    
    @Dependency(\.swiftDataClient) var swiftDataClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                
            case .viewAppeared:
                state.isLoading = true
                
                return .run { send in
                    let tasks = try await swiftDataClient.fetchTasks()
                    let taskValues = tasks.map { task in
                        TaskValue(
                            id: task.id,
                            title: task.title,
                            isCompleted: task.isCompleted,
                            createdAt: task.createdAt
                        )
                    }
                    await send(.tasksLoaded(taskValues))
                }
                
            case let .tasksLoaded(tasks):
                state.tasks = tasks
                state.isLoading = false
                return .none
                
            case let .taskToggled(id):
                guard let index = state.tasks.firstIndex(where: { $0.id == id }) else {
                    return .none
                }
                
                state.tasks[index].isCompleted.toggle()
                let isCompleted = state.tasks[index].isCompleted
                
                return .run { send in
                    try await swiftDataClient.updateTask(id, isCompleted)
                }
                
            case let .addTask(title):
                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return .none
                }
                
                let newTask = TaskValue(
                    id: UUID(),
                    title: title,
                    isCompleted: false,
                    createdAt: .now
                )
                
                state.tasks.append(newTask)
                state.newTaskTitle = ""
                
                return .run { send in
                    try await swiftDataClient.saveTask(title, false)
                    await send(.taskSaved)
                }
                
            case let .deleteTask(id):
                state.tasks.removeAll { $0.id == id }
                
                return .run { send in
                    try await swiftDataClient.deleteTask(id)
                }
                
            case .taskSaved:
                return .none
            }
        }
    }
}
