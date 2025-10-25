//
//  DailyAssessmentFeature.swift
//  Depresso
//
//  Created by ElAmir Mansour on 24/10/2025.
//

// In Features/Dashboard/DailyAssessmentFeature.swift
import Foundation
import ComposableArchitecture
import SwiftData

@Reducer
struct DailyAssessmentFeature {
    @ObservableState
    struct State: Equatable {
        var questions: [PHQ8.Question] = PHQ8.allQuestions // Re-use questions
        var currentQuestionIndex: Int = 0
        var isCompleted: Bool = false

        var progress: Double {
            Double(currentQuestionIndex) / Double(questions.count)
        }
        var isNextButtonEnabled: Bool {
            questions[currentQuestionIndex].answer != nil
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case answerQuestion(index: Int, answer: PHQ8.Answer)
        case nextButtonTapped
        case backButtonTapped
        case saveAssessment // New action
        case delegate(Delegate)

        enum Delegate {
            case assessmentCompleted(DailyAssessment)
            case cancel
        }
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.date.now) var now // Use dependency for date

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .answerQuestion(index, answer):
                state.questions[index].answer = answer
                return .none

            case .nextButtonTapped:
                if state.currentQuestionIndex < state.questions.count - 1 {
                    state.currentQuestionIndex += 1
                } else {
                    // Instead of showing analysis, trigger save
                    state.isCompleted = true // Mark as complete to show save button
                    return .send(.saveAssessment)
                }
                return .none

            case .backButtonTapped:
                if state.currentQuestionIndex > 0 {
                    state.currentQuestionIndex -= 1
                }
                return .none

            case .saveAssessment:
                let score = state.questions.compactMap(\.answer?.rawValue).reduce(0, +)
                let assessment = DailyAssessment(date: now, score: score)
                // Send back to parent and dismiss
                return .run { send in
                    await send(.delegate(.assessmentCompleted(assessment)))
                    await self.dismiss()
                }

            case .delegate(.cancel): // Handle explicit cancel if needed
                 return .run { _ in await self.dismiss() }

            case .binding, .delegate:
                return .none
            }
        }
    }
}
