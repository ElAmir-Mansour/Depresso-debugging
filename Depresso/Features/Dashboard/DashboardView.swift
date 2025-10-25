// In Features/Dashboard/DashboardView.swift
import SwiftUI
import ComposableArchitecture
import Charts
import SwiftData

struct DashboardView: View {
    @Bindable var store: StoreOf<DashboardFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    healthMetricsSection
                    dailyAssessmentSection
                    weeklyStepsSection
                    WellnessTasksView( // Assumes this view is defined correctly elsewhere
                        store: store.scope(state: \.wellnessTasksState, action: \.wellnessTasks)
                    )
                }
                .padding()
            }
            .background(Color.ds.backgroundPrimary)
            .navigationTitle("Dashboard")
            .task { await store.send(.task).finish() }
            .sheet(item: $store.scope(state: \.destination?.dailyAssessment, action: \.destination.dailyAssessment)) { assessmentStore in
                 DailyAssessmentView(store: assessmentStore) // Assumes this view is defined
            }
        }
    }

    // MARK: - Helper View Builders
    @ViewBuilder private var healthMetricsSection: some View {
         VStack(alignment: .leading) {
             Text("Today's Vitals").font(.ds.headline)
             if store.isLoading {
                 ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
             } else if store.healthMetrics.isEmpty {
                  Text("No health data available.").font(.ds.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center).padding()
             } else {
                 LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                     ForEach(store.healthMetrics) { metric in
                         MetricCardView(metric: metric) // Assumes defined elsewhere
                     }
                 }
             }
         }
    }
    @ViewBuilder private var dailyAssessmentSection: some View {
         VStack(alignment: .leading) {
             HStack {
                  Text("Mood Trend (PHQ-8)").font(.ds.headline)
                  Spacer()
                  Button { store.send(.takeAssessmentButtonTapped) } label: {
                      Label("Check-in", systemImage: "pencil.and.list.clipboard")
                  }
                  .buttonStyle(.bordered).tint(.ds.accent).disabled(!store.canTakeAssessmentToday)
             }
             if store.assessmentHistory.isEmpty && !store.isLoading {
                  Text("Complete your first daily check-in...").font(.ds.caption).foregroundStyle(.secondary).padding().frame(maxWidth: .infinity, alignment: .center)
             } else if !store.assessmentHistory.isEmpty {
                  AssessmentChartView(history: store.assessmentHistory).frame(height: 150)
             } else { // Loading placeholder
                  RoundedRectangle(cornerRadius: 8).fill(Color(UIColor.systemGray6)).frame(height: 150).overlay(ProgressView())
             }
         }
     }
    @ViewBuilder private var weeklyStepsSection: some View {
           VStack(alignment: .leading) {
              Text("Weekly Steps").font(.ds.headline)
              if store.isLoading {
                   RoundedRectangle(cornerRadius: 8).fill(Color(UIColor.systemGray6)).frame(height: 150).overlay(ProgressView())
              } else if store.weeklySteps.isEmpty {
                   Text("No step data available.").font(.ds.caption).foregroundStyle(.secondary).padding().frame(maxWidth: .infinity, alignment: .center)
              } else {
                  StepsChartView(stepsData: store.weeklySteps).frame(height: 150)
              }
          }
      }
}

// MARK: - Chart Views
struct StepsChartView: View {
     let stepsData: [StepData] // Defined in HealthClient.swift
     var body: some View {
         Chart(stepsData) { data in BarMark(x: .value("Day", data.date, unit: .day), y: .value("Steps", data.count)).foregroundStyle(Color.ds.accent.gradient) }
         .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true) } }
         .chartYAxis { AxisMarks(position: .leading) }
     }
 }
struct AssessmentChartView: View {
     let history: [DailyAssessment] // Defined in Core/Data
     private var yDomain: ClosedRange<Int> {
          let scores = history.map { $0.score }; let minScore = scores.min() ?? 0; let maxScore = scores.max() ?? 24
          return (minScore > 2 ? minScore - 2 : 0)...(maxScore < 22 ? maxScore + 2 : 24)
     }
     var body: some View {
         Chart(history) { assessment in
             LineMark(x: .value("Date", assessment.date, unit: .day), y: .value("Score", assessment.score)).interpolationMethod(.catmullRom).foregroundStyle(Color.ds.accent)
             PointMark(x: .value("Date", assessment.date, unit: .day), y: .value("Score", assessment.score)).foregroundStyle(Color.ds.accent).symbolSize(CGSize(width: 8, height: 8))
         }
         .chartYScale(domain: yDomain)
         .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true) } }
         .chartYAxis { AxisMarks(preset: .automatic, position: .leading) }
     }
 }


// MARK: - Preview (Corrected)
#Preview {
    let container = try! ModelContainer(
        // ✅ Pass individual types correctly, NOT an array literal
        for: WellnessTask.self, DailyAssessment.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let today = Calendar.current.startOfDay(for: .now)
    let sampleHistory = (0..<7).map { index -> DailyAssessment in
        let date = Calendar.current.date(byAdding: .day, value: -index, to: today)!
        return DailyAssessment(date: date, score: Int.random(in: 5...15))
    }.reversed()
    let _ = { sampleHistory.forEach { context.insert($0) } }() // Insert sample data

    let initialState = DashboardFeature.State(
        healthMetrics: HealthMetric.mock, // Assumes defined in HealthMetric.swift
        weeklySteps: StepData.mock, // Assumes defined in HealthClient.swift
        isLoading: false,
        wellnessTasksState: .init(), // Provide default state
        assessmentHistory: Array(sampleHistory)
    )

    let store = Store(initialState: initialState) {
        DashboardFeature()
            .dependency(\.healthClient, .previewValue)
            .dependency(\.modelContext, try! ModelContextBox(context)) // Assumes ModelContextBox exists
    }

    DashboardView(store: store)
        .modelContainer(container) // Keep this modifier
}
