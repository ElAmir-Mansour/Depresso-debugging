// In Features/Dashboard/WellnessTasksFeature.swift
import Foundation
import ComposableArchitecture
import SwiftData
import SwiftUI

@Reducer
struct WellnessTasksFeature {
    // ... (State, Action enum are the same) ...
     @ObservableState
     struct State: Equatable {
         var tasks: [WellnessTask] = []
         var newTaskTitle: String = ""
     }

     enum Action: BindableAction {
         case binding(BindingAction<State>)
         case task
         case tasksLoaded([WellnessTask])
         case addTaskButtonTapped
         case toggleTaskCompletion(id: WellnessTask.ID)
         case deleteTask(IndexSet)
     }

    @Dependency(\.modelContext) var modelContext
    @Dependency(\.uuid) var uuid // Only needed if ID is required by init

    @MainActor
    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            // ... (task, tasksLoaded, binding are the same) ...
             case .task:
                  return .run { send in
                      let descriptor = FetchDescriptor<WellnessTask>(sortBy: [SortDescriptor(\.creationDate)])
                      let tasks = try modelContext.context.fetch(descriptor)
                      await send(.tasksLoaded(tasks))
                  }
             
             case .tasksLoaded(let tasks):
                  state.tasks = tasks
                  return .none

             case .binding(\.newTaskTitle):
                 return .none

            case .addTaskButtonTapped:
                let trimmedTitle = state.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { return .none }
                // ✅ Corrected Initializer: Assumes WellnessTask takes only 'title'
                // If it needs an ID: let newTask = WellnessTask(id: uuid(), title: trimmedTitle)
                let newTask = WellnessTask(title: trimmedTitle)
                state.tasks.append(newTask)
                state.newTaskTitle = ""
                modelContext.context.insert(newTask)
                do { try modelContext.context.save() } catch { print("Error saving new task: \(error)") }
                return .none

            // ... (toggleTaskCompletion, deleteTask, binding are the same) ...
             case .toggleTaskCompletion(let id):
                 guard let index = state.tasks.firstIndex(where: { $0.id == id }) else { return .none }
                 state.tasks[index].isCompleted.toggle()
                  do { try modelContext.context.save() } catch { print("Error saving task completion: \(error)") }
                 return .none

             case .deleteTask(let offsets):
                 let tasksToDelete = offsets.map { state.tasks[$0] }
                 state.tasks.remove(atOffsets: offsets)
                  do {
                      for task in tasksToDelete { modelContext.context.delete(task) }
                      try modelContext.context.save()
                  } catch { print("Error deleting task: \(error)") }
                 return .none

             case .binding:
                 return .none
            }
        }
    }
}

// ... (WellnessTasksView, TaskRowView definitions remain the same) ...
 struct WellnessTasksView: View { /* ... same ... */
     @Bindable var store: StoreOf<WellnessTasksFeature>

     var body: some View {
         VStack(alignment: .leading) {
             Text("Today's Goals")
                 .font(.ds.headline)

             // Use List for deletable rows
             List {
                  ForEach(store.tasks) { task in
                     TaskRowView(task: task) {
                         store.send(.toggleTaskCompletion(id: task.id))
                     }
                 }
                 .onDelete { indexSet in
                     store.send(.deleteTask(indexSet))
                 }
             }
             .listStyle(.plain) // Use plain style to embed in VStack
             // Adjust height dynamically or set fixed height
             // Be careful with dynamic height inside ScrollView, might need GeometryReader or fixed frame
             .frame(minHeight: CGFloat(store.tasks.count * 44), maxHeight: 200)


             HStack {
                 TextField("Add a new goal...", text: $store.newTaskTitle)
                     .textFieldStyle(.roundedBorder) // Added style for visibility
                  Button {
                      store.send(.addTaskButtonTapped)
                  } label: {
                      Image(systemName: "plus.circle.fill")
                         .resizable()
                         .frame(width: 24, height: 24) // Explicit frame for button size
                  }
                  .disabled(store.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
             }
             .padding(.top, DesignSystem.Spacing.small)
         }
         .onAppear { // Use onAppear for initial load in view if .task not used in parent
             if store.tasks.isEmpty { // Fetch only if empty on appear
                 store.send(.task)
             }
         }
     }
 }


 struct TaskRowView: View { /* ... same ... */
     let task: WellnessTask
     let onToggle: () -> Void

     var body: some View {
         HStack {
             Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                 .foregroundStyle(task.isCompleted ? Color.ds.accent : .secondary)
                 .onTapGesture { onToggle() } // Keep toggle on image
             Text(task.title)
                 .strikethrough(task.isCompleted, color: .secondary)
                 .foregroundStyle(task.isCompleted ? .secondary : .primary)
             Spacer()
         }
         .contentShape(Rectangle())
     }
 }
