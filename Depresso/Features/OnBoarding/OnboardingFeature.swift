// In Features/Onboarding/OnboardingFeature.swift
import Foundation
import ComposableArchitecture

@Reducer
struct OnboardingFeature {
    // ... (State remains the same) ...
     @ObservableState
     struct State: Equatable {
         var questions: [PHQ8.Question] = PHQ8.allQuestions
         var currentQuestionIndex: Int = 0
         var isCompleted: Bool = false // Indicates PHQ8 is done, showing analysis view
         var analysis: String?
         var isLoadingAnalysis: Bool = false

         // Score and Severity
         var finalScore: Int = 0
         var severity: String = ""

         var progress: Double {
             // Progress based on answering questions, not just viewing them
             let answeredCount = questions.prefix(currentQuestionIndex + 1).filter { $0.answer != nil }.count
             return Double(answeredCount) / Double(questions.count)
         }

         var isNextButtonEnabled: Bool {
             // Enable next/finish only if the *current* question has an answer
             questions[currentQuestionIndex].answer != nil
         }
     }


    // ... (Action remains the same) ...
     enum Action {
         case answerQuestion(index: Int, answer: PHQ8.Answer)
         case nextButtonTapped
         case backButtonTapped
         case getAnalysisButtonTapped
         case analysisResponse(Result<String, Error>)
         case delegate(Delegate)

         @CasePathable // Needed for delegate actions
         enum Delegate {
             case onboardingCompleted // No data needed, just signal completion
         }
     }


    @Dependency(\.aiClient) var aiClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.date.now) var now

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            // ... (cases .answerQuestion, .nextButtonTapped, .backButtonTapped remain the same as previous correction) ...
             case let .answerQuestion(index, answer):
                  guard index == state.currentQuestionIndex else { return .none } // Only allow answering current question
                 state.questions[index].answer = answer
                 // Automatically move to next question or finish
                 if state.currentQuestionIndex < state.questions.count - 1 {
                      // return .send(.nextButtonTapped) // Optional: Auto-advance
                  } else {
                      // Last question answered, calculate score and mark as ready for analysis
                      calculateScoreAndSeverity(&state)
                      state.isCompleted = true
                      // Fetch analysis automatically once completed
                      if state.analysis == nil && !state.isLoadingAnalysis {
                           return .send(.getAnalysisButtonTapped)
                       }
                  }
                 return .none

             case .nextButtonTapped:
                  guard state.isNextButtonEnabled else { return .none } // Should be disabled if no answer

                 if state.currentQuestionIndex < state.questions.count - 1 {
                     state.currentQuestionIndex += 1
                 } else if !state.isCompleted {
                      // This case handles pressing "Finish" on the last question if auto-advance isn't used
                      calculateScoreAndSeverity(&state)
                      state.isCompleted = true
                      // Fetch analysis automatically
                      if state.analysis == nil && !state.isLoadingAnalysis {
                           return .send(.getAnalysisButtonTapped)
                       }
                  }
                 return .none

             case .backButtonTapped:
                 if state.currentQuestionIndex > 0 {
                     state.currentQuestionIndex -= 1
                     state.isCompleted = false // No longer on the final analysis screen
                 }
                 return .none


            case .getAnalysisButtonTapped:
                 guard state.isCompleted else { return .none }
                state.isLoadingAnalysis = true

                if state.finalScore == 0 && state.severity.isEmpty {
                   calculateScoreAndSeverity(&state)
                }

                let scoreToSave = state.finalScore
                let dateToSave = now
                let prompt = createAnalysisPrompt(score: state.finalScore, severity: state.severity)

                // **FIX:** Capture dependencies explicitly before the async operation
                let localUserDefaultsClient = self.userDefaultsClient
                let localAIClient = self.aiClient

                return .run { send in
                    // Use captured dependency
                    try await userDefaultsClient.savePHQ8Score(scoreToSave)

                    do {
                        // Use captured dependency
                        let response = try await localAIClient.generateResponse([], prompt, nil)
                        await send(.analysisResponse(.success(response)))
                    } catch {
                        await send(.analysisResponse(.failure(error)))
                    }
                }

            // ... (cases .analysisResponse remain the same) ...
             case .analysisResponse(.success(let analysis)):
                 state.isLoadingAnalysis = false
                 state.analysis = analysis
                 return .none

             case .analysisResponse(.failure(let error)):
                 state.isLoadingAnalysis = false
                 state.analysis = "Sorry, we couldn't generate your analysis at this time. Please check your connection and try again.\n(\(error.localizedDescription))"
                 return .none


            case .delegate(.onboardingCompleted):
                let onboardingCompletionDate = now
                // **FIX:** Capture dependency explicitly
                let localUserDefaultsClient = self.userDefaultsClient
                return .run { _ in
                    // Use captured dependency
                    do {
                        try await localUserDefaultsClient.saveOnboardingDate(onboardingCompletionDate)
                        print(" MOCK Onboarding completed and date saved.")
                    } catch {
                        print("Failed saving onboarding date: \(error)")
                    }

                }

             case .delegate:
                 return .none
            }
        }
    }

    // ... (Helper functions calculateScoreAndSeverity, getSeverity, createAnalysisPrompt remain the same) ...
     private func calculateScoreAndSeverity(_ state: inout State) {
          let score = state.questions.compactMap(\.answer?.rawValue).reduce(0, +)
          state.finalScore = score
          state.severity = getSeverity(for: score)
      }


     // Function to determine severity based on score
     private func getSeverity(for score: Int) -> String {
         switch score {
         case 0...4: return "Minimal Symptoms"
         case 5...9: return "Mild Symptoms"
         case 10...14: return "Moderate Symptoms"
         case 15...19: return "Moderately Severe Symptoms"
         default: return "Severe Symptoms" // 20-24
         }
     }

     // Function to create the AI prompt
     private func createAnalysisPrompt(score: Int, severity: String) -> String {
        // Your existing prompt creation logic remains the same
         return """
         A user has completed the PHQ-8 questionnaire and scored \(score), which indicates \(severity.lowercased()) depression symptoms.
         Based on this, please provide a brief, supportive, and encouraging analysis written directly to the user.

         - Start with a reassuring and empathetic tone. Acknowledge their effort in completing the check-in.
         - Briefly explain what the score suggests in simple, non-clinical terms (e.g., "This score suggests you've been experiencing [severity] feelings more often recently.").
         - Highlight that this is just a snapshot and not a diagnosis.
         - Gently suggest that the app's features (like the journal, wellness tasks, and community) can be helpful tools for understanding and managing their feelings.
         - Frame the app as a supportive companion for their mental wellness journey. Encourage exploration of the app.
         - Keep the analysis concise, ideally 2-3 short paragraphs.
         - Maintain a warm, hopeful, and non-judgmental tone.

         IMPORTANT: Your entire response will be shown directly to the user. Do not include any of your own thoughts, XML tags, placeholders like "[App Name]", or any text that is not part of the final, user-facing analysis. Avoid giving medical advice or instructions.
         """
     }
}
