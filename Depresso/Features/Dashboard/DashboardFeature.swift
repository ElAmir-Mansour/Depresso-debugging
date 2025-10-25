// In Features/Dashboard/DashboardFeature.swift
import Foundation
import ComposableArchitecture
import SwiftData
import Charts

@Reducer
struct DashboardFeature {
    @ObservableState
    struct State: Equatable {
        // ✅ Added explicit Equatable now that StepData is defined and Equatable
        static func == (lhs: DashboardFeature.State, rhs: DashboardFeature.State) -> Bool {
            return lhs.healthMetrics == rhs.healthMetrics &&
                   lhs.weeklySteps == rhs.weeklySteps &&
                   lhs.isLoading == rhs.isLoading &&
                   lhs.wellnessTasksState == rhs.wellnessTasksState &&
                   lhs.assessmentHistory.map(\.id) == rhs.assessmentHistory.map(\.id) &&
                   lhs.canTakeAssessmentToday == rhs.canTakeAssessmentToday &&
                   lhs.destination == rhs.destination
        }

        var healthMetrics: [HealthMetric] = []
        var weeklySteps: [StepData] = [] // StepData is now defined in HealthClient.swift
        var isLoading: Bool = true
        var wellnessTasksState = WellnessTasksFeature.State() // Assumes defined
        var assessmentHistory: [DailyAssessment] = [] // Assumes defined
        var canTakeAssessmentToday: Bool = true
        @Presents var destination: Destination.State?
    }

     enum Action {
         case task
         case healthDataLoaded(Result<([HealthMetric], [StepData]), Error>) // Type matches
         case wellnessTasks(WellnessTasksFeature.Action)
         case assessmentHistoryLoaded(Result<[DailyAssessment], Error>)
         case takeAssessmentButtonTapped
         case destination(PresentationAction<Destination.Action>)
         case checkForAssessmentStatus
     }
     @Reducer(state: .equatable)
     enum Destination {
         case dailyAssessment(DailyAssessmentFeature) // Assumes defined
     }
     @Dependency(\.healthClient) var healthClient
     @Dependency(\.modelContext) var modelContext
     @Dependency(\.date.now) var now

    @MainActor
    var body: some Reducer<State, Action> {
        Scope(state: \.wellnessTasksState, action: \.wellnessTasks) {
            WellnessTasksFeature() // Assumes defined
        }

        Reduce { state, action in
            switch action {
             case .task:
                  state.isLoading = true
                  return .merge(
                      .run { send in
                          // Request auth first if needed
                          try? await healthClient.requestAuthorization()
                          // Then fetch data
                          await send(.healthDataLoaded(Result {
                              try await (healthClient.fetchHealthMetrics(), healthClient.fetchWeeklySteps())
                          }))
                      },
                      .run { send in
                           let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
                           let predicate = #Predicate<DailyAssessment> { $0.date >= sevenDaysAgo }
                           let descriptor = FetchDescriptor<DailyAssessment>(predicate: predicate, sortBy: [SortDescriptor(\.date)])
                           // Use .context to access the actual ModelContext
                           await send(.assessmentHistoryLoaded(Result { try modelContext.context.fetch(descriptor) }))
                       },
                       .send(.checkForAssessmentStatus)
                  )

             case .healthDataLoaded(.success(let (metrics, steps))):
                 state.healthMetrics = metrics
                 state.weeklySteps = steps
                 state.isLoading = false
                 return .none

             case .healthDataLoaded(.failure(let error)):
                 state.isLoading = false
                 print("Error loading health data: \(error)")
                 return .none

             case .wellnessTasks: // Actions scoped to WellnessTasksFeature
                 return .none

             case .assessmentHistoryLoaded(.success(let history)):
                  state.assessmentHistory = history
                  return .send(.checkForAssessmentStatus) // Re-check after loading

             case .assessmentHistoryLoaded(.failure(let error)):
                  print("Error loading assessment history: \(error)")
                  state.canTakeAssessmentToday = true // Default to allow if load fails
                  return .none

             case .checkForAssessmentStatus:
                  let startOfToday = Calendar.current.startOfDay(for: now)
                  // Check if any loaded assessment matches today's date
                  state.canTakeAssessmentToday = !state.assessmentHistory.contains { Calendar.current.isDate($0.date, inSameDayAs: startOfToday) }
                  return .none

             case .takeAssessmentButtonTapped:
                  state.destination = .dailyAssessment(.init()) // Assumes DailyAssessmentFeature exists
                  return .none

             // Handle result from the DailyAssessment sheet
             case .destination(.presented(.dailyAssessment(.delegate(.assessmentCompleted(let assessment))))):
                  // Insert and save the new assessment using .context
                  modelContext.context.insert(assessment)
                  do {
                      try modelContext.context.save()
                      print("✅ Daily assessment saved.")
                      // Update local state *after* successful save
                      state.assessmentHistory.append(assessment)
                      state.assessmentHistory.sort { $0.date < $1.date } // Keep sorted
                      state.destination = nil // Dismiss sheet state
                      return .send(.checkForAssessmentStatus) // Re-check button status
                  } catch {
                      print("❌ Failed to save daily assessment: \(error)")
                       state.destination = nil // Dismiss sheet state even on error
                      return .none
                  }

             case .destination(.dismiss):
                  state.destination = nil
                  return .none

             case .destination:
                  return .none
            }
        }
        .ifLet(\.$destination, action: \.destination) // Manage the sheet presentation
    }
}
