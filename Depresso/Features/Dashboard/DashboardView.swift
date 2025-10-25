// Depresso/Features/Dashboard/DashboardView.swift

import SwiftUI
import ComposableArchitecture
import Charts

struct DashboardView: View {
    let store: StoreOf<DashboardFeature>
    
    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HeaderSection()
                    
                    // Health Vitals Card
                    if store.isLoadingHealth {
                        ProgressView("Loading health data...")
                    } else if let error = store.healthError {
                        ErrorCard(message: error, onRetry: {
                            store.send(.refreshTapped)
                        })
                    } else {
                        VitalsCard(
                            steps: store.todaySteps,
                            heartRate: store.heartRate,
                            activeEnergy: store.activeEnergy
                        )
                        
                        // Weekly Steps Chart
                        WeeklyStepsChart(data: store.weeklySteps)
                    }
                    
                    // Wellness Tasks Section
                    TasksSectionView(
                        store: store.scope(
                            state: \.tasks,
                            action: \.tasks
                        ),
                        onAddTask: { store.send(.addTaskButtonTapped) }
                    )
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .onAppear {
                store.send(.viewAppeared)
            }
            .refreshable {
                store.send(.refreshTapped)
            }
            .sheet(isPresented: $store.showAddTask.sending(\.dismissAddTask)) {
                AddTaskSheet(store: store.scope(
                    state: \.tasks,
                    action: \.tasks
                ))
            }
        }
    }
}

struct HeaderSection: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome Back")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(Date.now, style: .date)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.pink.gradient)
        }
    }
}

struct VitalsCard: View {
    let steps: Int
    let heartRate: Int
    let activeEnergy: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Health")
                .font(.headline)
            
            HStack(spacing: 20) {
                VitalItem(
                    icon: "figure.walk",
                    value: "\(steps)",
                    unit: "steps",
                    color: .blue
                )
                
                Divider()
                
                VitalItem(
                    icon: "heart.fill",
                    value: "\(heartRate)",
                    unit: "bpm",
                    color: .red
                )
                
                Divider()
                
                VitalItem(
                    icon: "flame.fill",
                    value: "\(activeEnergy)",
                    unit: "cal",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct VitalItem: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WeeklyStepsChart: View {
    let data: [DailySteps]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Steps")
                .font(.headline)
            
            Chart(data) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Steps", day.steps)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.weekday(.narrow))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct TasksSectionView: View {
    let store: StoreOf<TasksFeature>
    let onAddTask: () -> Void
    
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Daily Wellness Goals")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: onAddTask) {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                    }
                }
                
                if store.isLoading {
                    ProgressView()
                } else if store.tasks.isEmpty {
                    EmptyTasksView(onAddTask: onAddTask)
                } else {
                    ForEach(store.tasks) { task in
                        TaskRow(
                            task: task,
                            onToggle: { store.send(.taskToggled(task.id)) },
                            onDelete: { store.send(.deleteTask(task.id)) }
                        )
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .onAppear {
                store.send(.viewAppeared)
            }
        }
    }
}

struct TaskRow: View {
    let task: TasksFeature.TaskValue
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            
            Text(task.title)
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
    }
}

struct EmptyTasksView: View {
    let onAddTask: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No wellness goals yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Add Your First Goal", action: onAddTask)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct AddTaskSheet: View {
    let store: StoreOf<TasksFeature>
    @Environment(\.dismiss) var dismiss
    @State private var taskTitle: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("New Wellness Goal") {
                    TextField("E.g., Drink 8 glasses of water", text: $taskTitle)
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.send(.addTask(taskTitle))
                        dismiss()
                    }
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
