// In Features/Journal/AICompanionJournalFeature.swift
import Foundation
import ComposableArchitecture
// ... other imports ...
import SwiftData
import CoreMotion
import FirebaseAI
import SwiftUI


@Reducer
struct AICompanionJournalFeature {
    // ... (CancelID, State, Action enums remain largely the same as previous correction) ...
     private enum CancelID { case motion, submitDebounce }

     @ObservableState
     struct State: Equatable {
         // Simple equality check focusing on key identifiable/changing elements
         static func == (lhs: State, rhs: State) -> Bool {
             lhs.messages.map(\.id) == rhs.messages.map(\.id) &&
             lhs.textInput == rhs.textInput &&
             lhs.isSendingMessage == rhs.isSendingMessage &&
             lhs.isSubmittingBehavioralData == rhs.isSubmittingBehavioralData && // Added
             lhs.behavioralDataSubmissionError == rhs.behavioralDataSubmissionError // Added
         }

         var messages: [ChatMessage] = []
         var textInput: String = ""
         var isSendingMessage: Bool = false
         @Presents var alert: AlertState<Action.Alert>?

         // Session & Metrics Tracking
         var currentSessionId: UUID? // ID for the current data submission session
         var journalSessionStartDate: Date?
         var lastWordCount: Int = 0
         var editCount: Int = 0
         var motionSamples: [CMAcceleration] = []
         var lastPHQ8Score: Int? // Store the score
         var onboardingDate: Date? // Store onboarding date

         // Properties for calculating metrics at submission time
         var currentWPM: Double = 0
         var currentSessionDuration: TimeInterval = 0
         var currentMotionData: [CMAcceleration] = []
         var currentEditCountForSubmission: Int = 0
         var currentJournalEntryLength: Int = 0

         // Data Submission State (Added from Snippet)
         var isSubmittingBehavioralData: Bool = false
         var behavioralDataSubmissionError: String?
         var lastSubmissionId: String?
     }

     enum Action: BindableAction {
         case binding(BindingAction<State>)
         case task
         case onDisappear // Added for potential submission on exit

         // Message Handling
         case sendButtonTapped
         case userMessageSaved(Result<ChatMessage, Error>)
         case aiResponseReceived(Result<ChatMessage, Error>) // Renamed from aiMessageSaved for clarity
         case aiMessageSaved(Result<ChatMessage, Error>) // Separate action for saving AI response

         // Data Loading
         case messagesLoaded(Result<[ChatMessage], Error>)
         case loadInitialData // Separate action to load PHQ8 score and onboarding date

         // Metrics Collection
         case motionUpdate(MotionData)
         case userTyped // Action for tracking typing metrics
         case userDidBackspace

         // Data Submission (Added from Snippet)
         case submitBehavioralData
         case behavioralDataSubmitted(Result<DataSubmissionResponse, Error>)
         case dismissSubmissionError

         // Alerts
         case alert(PresentationAction<Alert>)
         @CasePathable
         enum Alert: Equatable {}
         
         case initialDataLoaded(phq8Score: Int?, onboardingDate: Date?)
         case setOnboardingDate(Date)


     }


    // ... (Dependencies remain the same) ...
     @Dependency(\.aiClient) var aiClient
     @Dependency(\.motionClient) var motionClient
     // @Dependency(\.healthClient) var healthClient // Commented out as not used in submission snippet
     @Dependency(\.dataSubmissionClient) var dataSubmissionClient
     @Dependency(\.userDefaultsClient) var userDefaultsClient // Added
     @Dependency(\.uuid) var uuid
     @Dependency(\.date.now) var now
     @Dependency(\.modelContext) var modelContext
     @Dependency(\.continuousClock) var clock // For debouncing

     // Access current user for consent check
     @Dependency(\.currentUser) var currentUser


    // ... (history helper function remains the same) ...
     private func history(from messages: [ChatMessage]) -> [ModelContent] {
          messages.map { message in
              let role = message.isFromCurrentUser ? "user" : "model" // FirebaseAI uses 'user'/'model'
              // Assuming ModelContent Part takes a String directly
              return ModelContent(role: role, parts: [message.content])
          }
     }


    @MainActor
    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .task:
                state.currentSessionId = uuid()
                state.journalSessionStartDate = now
                state.motionSamples = []
                state.editCount = 0
                state.lastWordCount = 0

                // **FIX:** Capture dependencies explicitly
                let localModelContext = self.modelContext
                let localMotionClient = self.motionClient

                return .merge(
                    .run { send in
                        let descriptor = FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.timestamp)])
                        // Use captured dependency
                        await send(.messagesLoaded(Result { try localModelContext.context.fetch(descriptor) }))
                    },
                    .run { send in
                         // Use captured dependency
                        for await motionData in localMotionClient.start() {
                            await send(.motionUpdate(motionData))
                        }
                    }
                    .cancellable(id: CancelID.motion),
                    .send(.loadInitialData)
                )

            // ... (case .onDisappear remains the same) ...
             case .onDisappear:
                  // Cancel motion updates
                  // Consider submitting data here if the session should end on disappear
                  return .concatenate(
                      .cancel(id: CancelID.motion),
                      .send(.submitBehavioralData) // Submit data when view disappears
                  )

            case .loadInitialData:
                let localUserDefaultsClient = self.userDefaultsClient
                return .run { send in
                    let score = try? await localUserDefaultsClient.getLastPHQ8Score()
                    let date = try? await localUserDefaultsClient.getOnboardingDate()
                    await send(.initialDataLoaded(phq8Score: score, onboardingDate: date))
                }

            case .initialDataLoaded(let score, let date):
                state.lastPHQ8Score = score
                state.onboardingDate = date
                return .none

            // ... (cases .messagesLoaded, .motionUpdate, .userTyped, .userDidBackspace remain the same) ...
             case .messagesLoaded(.success(let messages)):
                 state.messages = messages
                 // Add initial greeting if no messages exist
                 if messages.isEmpty {
                     let greeting = ChatMessage(timestamp: now, content: "Hello! How are you feeling today?", isFromCurrentUser: false)
                      // Insert initial greeting into SwiftData as well
                      modelContext.context.insert(greeting)
                      do { try modelContext.context.save() } catch {} // Ignore save error for greeting
                     state.messages.append(greeting)
                 }
                 return .none

             case .messagesLoaded(.failure(let error)):
                 state.alert = AlertState { TextState("Error") } message: { TextState("Could not load journal history: \(error.localizedDescription)") }
                 return .none

             case .motionUpdate(let motionData):
                 // Append motion data, consider capping the array size if needed
                 state.motionSamples.append(motionData.userAcceleration)
                 return .none

              case .userTyped:
                   // Calculate WPM dynamically or update word count for later calculation
                   // This is a simplified way to track typing for WPM calc later
                   let currentWordCount = state.textInput.split(whereSeparator: \.isWhitespace).count
                   state.lastWordCount = currentWordCount
                   return .none // No immediate effect needed, just tracks state

             case .userDidBackspace:
                 state.editCount += 1
                 return .none


            case .sendButtonTapped:
                let trimmedInput = state.textInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedInput.isEmpty else { return .none }

                let userMessage = ChatMessage(id: uuid(), timestamp: now, content: trimmedInput, isFromCurrentUser: true)
                let prompt = trimmedInput

                state.isSendingMessage = true

                // --- Capture Metrics ---
                 let sessionEndTime = now
                 let duration = sessionEndTime.timeIntervalSince(state.journalSessionStartDate ?? sessionEndTime)
                 state.currentSessionDuration = duration
                 state.currentJournalEntryLength = userMessage.content.count // Length of the message being sent
                 state.currentMotionData = state.motionSamples
                 state.currentEditCountForSubmission = state.editCount
                 let wordCount = userMessage.content.split(whereSeparator: \.isWhitespace).count
                 state.currentWPM = duration > 1 ? (Double(wordCount) / duration) * 60.0 : 0

                // --- Prepare for Next Session ---
                let historyForAI = history(from: state.messages)
                state.textInput = ""
                state.journalSessionStartDate = sessionEndTime
                state.editCount = 0
                state.motionSamples = []
                state.lastWordCount = 0

                // **FIX:** Capture dependencies explicitly
                let localModelContext = self.modelContext
                let localAIClient = self.aiClient
                let localNow = self.now // Capture Date dependency if used inside Task
                let localUUID = self.uuid // Capture UUID if used inside Task
                let localClock = self.clock // Capture Clock


                return .run { send in
                    // 1. Save User Message (Use captured context)
                    localModelContext.context.insert(userMessage)
                    do {
                        try localModelContext.context.save()
                        await send(.userMessageSaved(.success(userMessage)))
                    } catch {
                        await send(.userMessageSaved(.failure(error)))
                        return

                    }

                    // 2. Get AI Response (Use captured client and date)
                    do {
                        let systemPrompt = "You are a friendly journaling companion focusing on mental wellness. Be supportive and empathetic. Keep responses concise."
                        let responseText = try await localAIClient.generateResponse(historyForAI, prompt, systemPrompt)
                        let aiMessage = ChatMessage(id: localUUID(), timestamp: localNow, content: responseText, isFromCurrentUser: false)
                        await send(.aiResponseReceived(.success(aiMessage)))
                    } catch {
                        await send(.aiResponseReceived(.failure(error)))
                    }

                    // 3. Submit Behavioral Data (Use captured clock)
                    try await localClock.sleep(for: .seconds(1))
                    await send(.submitBehavioralData)

                }
                .cancellable(id: CancelID.submitDebounce, cancelInFlight: true)

             // ... (case .userMessageSaved remains the same) ...
              case .userMessageSaved(.success(let message)):
                  // Add message to local state for UI update *after* successful save
                   if !state.messages.contains(where: { $0.id == message.id }) {
                       state.messages.append(message)
                   }
                  // Don't turn off isSendingMessage here, wait for AI response
                  return .none

              case .userMessageSaved(.failure(let error)):
                  state.isSendingMessage = false // Stop loading indicator
                  state.alert = AlertState { TextState("Save Error") } message: { TextState("Could not save your message: \(error.localizedDescription)") }
                  return .none


            case .aiResponseReceived(.success(let aiMessage)):
                // **FIX:** Capture dependency explicitly
                let localModelContext = self.modelContext
                return .run { send in
                    // Use captured context
                    localModelContext.context.insert(aiMessage)
                    do {
                        try localModelContext.context.save()
                        await send(.aiMessageSaved(.success(aiMessage)))
                    } catch {
                        await send(.aiMessageSaved(.failure(error)))
                    }
                }

             // ... (cases .aiResponseReceived(.failure), .aiMessageSaved remain the same) ...
              case .aiResponseReceived(.failure(let error)):
                  state.isSendingMessage = false // Stop loading indicator on AI error
                  // Optionally create a placeholder "error" message bubble
                let errorMessage = ChatMessage(id: uuid(), timestamp: now, content: "Sorry, I couldn't generate a response. Please try again.", isFromCurrentUser: false)
                  state.messages.append(errorMessage)
                  // Or show an alert
                  // state.alert = AlertState { TextState("AI Error") } message: { TextState("Failed to get AI response: \(error.localizedDescription)") }
                  return .none


              case .aiMessageSaved(.success(let message)):
                  state.isSendingMessage = false // Stop loading indicator *after* AI message is saved
                  // Add AI message to local state for UI update
                  if !state.messages.contains(where: { $0.id == message.id }) {
                      state.messages.append(message)
                  }
                  return .none

              case .aiMessageSaved(.failure(let error)):
                  state.isSendingMessage = false // Stop loading indicator
                  state.alert = AlertState { TextState("Save Error") } message: { TextState("Could not save the AI response: \(error.localizedDescription)") }
                  return .none


            case .submitBehavioralData:
                 // ... (submission logic remains the same, capture dependencies if needed) ...
                 guard let sessionId = state.currentSessionId else {
                      print("⚠️ Attempted to submit behavioral data without a session ID.")
                      return .none // No session ID, cannot submit
                  }

                 // Check consent *before* making the API call
                 guard let user = currentUser, user.hasGrantedResearchConsent else {
                     print(" MOCK Skipping behavioral data submission: Consent not granted.")
                     return .none // User hasn't consented, skip submission silently
                 }

                 state.isSubmittingBehavioralData = true
                 state.behavioralDataSubmissionError = nil

                 // --- Calculate Metrics ---
                 // Average Acceleration (Magnitude)
                 let count = Double(state.currentMotionData.count)
                 let avgMotionRaw = state.currentMotionData.reduce((x: 0.0, y: 0.0, z: 0.0)) {
                     (acc, sample) in (acc.x + sample.x, acc.y + sample.y, acc.z + sample.z)
                 }
                 let avgAccX = count > 0 ? avgMotionRaw.x / count : 0
                 let avgAccY = count > 0 ? avgMotionRaw.y / count : 0
                 let avgAccZ = count > 0 ? avgMotionRaw.z / count : 0
                 let avgAccelerationMagnitude = sqrt(avgAccX*avgAccX + avgAccY*avgAccY + avgAccZ*avgAccZ) // Calculate magnitude

                 // Acceleration Variance (optional, simplified example - variance of magnitude)
                  var accelerationVariance: Double? = nil
                  if count > 1 {
                      let magnitudes = state.currentMotionData.map { sqrt($0.x*$0.x + $0.y*$0.y + $0.z*$0.z) }
                      let meanMagnitude = magnitudes.reduce(0.0, +) / count
                      let varianceSum = magnitudes.reduce(0.0) { $0 + pow($1 - meanMagnitude, 2) }
                      accelerationVariance = varianceSum / (count - 1)
                  }


                 // Edit Rate
                 let editRate = state.currentSessionDuration > 0 ? Double(state.currentEditCountForSubmission) / state.currentSessionDuration : 0

                 // Create submission object
                 let submission = BehavioralDataSubmission(
                     sessionId: sessionId,
                     timestamp: now, // Timestamp of submission
                     wordsPerMinute: state.currentWPM,
                     totalEdits: state.currentEditCountForSubmission,
                     editRate: editRate,
                     avgAcceleration: avgAccelerationMagnitude, // Use magnitude
                     accelerationVariance: accelerationVariance,
                     motionSamples: state.currentMotionData.count,
                     durationSeconds: state.currentSessionDuration,
                     journalEntryLength: state.currentJournalEntryLength,
                     phq8Score: state.lastPHQ8Score, // Use stored score
                     timeOfDay: DataSubmissionClient.getTimeOfDay(from: now), // Use helper
                     daysSinceOnboarding: state.onboardingDate.map { // Use helper
                         DataSubmissionClient.daysSinceOnboarding(from: $0)
                     }
                 )

                 // Clear the captured metrics for this submission to avoid re-submitting stale data
                  state.currentMotionData = []
                  state.currentEditCountForSubmission = 0
                  state.currentSessionDuration = 0
                  state.currentWPM = 0
                  state.currentJournalEntryLength = 0
                  // Start a new session ID for the *next* submission
                  state.currentSessionId = uuid()

                 // **FIX:** Capture dependency explicitly
                 let localDataSubmissionClient = self.dataSubmissionClient

                 return .run { send in
                      // Use captured dependency
                     await send(.behavioralDataSubmitted(
                         Result {
                             try await localDataSubmissionClient.submitBehavioralData(submission)
                         }
                     ))
                 }

            // ... (cases .behavioralDataSubmitted, .dismissSubmissionError, .binding, .alert remain the same) ...
             case .behavioralDataSubmitted(.success(let response)):
                 state.isSubmittingBehavioralData = false
                 state.lastSubmissionId = response.submissionId
                 print("✅ Behavioral data submitted successfully: \(response.submissionId)")
                 // Optionally clear error message on success
                 // state.behavioralDataSubmissionError = nil
                 return .none

             case .behavioralDataSubmitted(.failure(let error)):
                 state.isSubmittingBehavioralData = false

                 // Handle specific error types for user feedback
                 if let submissionError = error as? DataSubmissionError {
                     switch submissionError {
                     case .consentNotGranted:
                         // Should ideally not happen due to pre-check, but handle defensively
                         state.behavioralDataSubmissionError = "Consent was revoked. Data not submitted."
                         // Maybe update user consent status?
                         return .none
                     case .rateLimited:
                         state.behavioralDataSubmissionError = "Data submission limit reached. Try later."
                         // Implement retry logic later if needed
                     case .tokenExpired:
                         // Token expired, signal parent (AppRootFeature) to refresh
                          state.behavioralDataSubmissionError = "Session expired. Refreshing..." // Temporary message
                          // This error should ideally trigger the TokenRefreshMiddleware via AppRootFeature
                          // No direct .send needed here if middleware catches 401s globally
                     case .notAuthenticated:
                          state.behavioralDataSubmissionError = "Authentication error. Please log in."
                          // May need to signal logout to parent
                     default:
                         state.behavioralDataSubmissionError = "Failed to submit data: \(error.localizedDescription)"
                     }
                 } else {
                     // Generic error
                     state.behavioralDataSubmissionError = "An unexpected error occurred: \(error.localizedDescription)"
                 }
                 print("❌ Behavioral data submission failed: \(error.localizedDescription)")
                 return .none

             case .dismissSubmissionError:
                 state.behavioralDataSubmissionError = nil
                 return .none


             // --- Other Cases ---
              case .binding(\.textInput):
                   // When text changes, send .userTyped to update metrics potentially
                   return .send(.userTyped) // Trigger metric update logic if needed here

             case .binding:
                 // Handle other bindings if necessary
                 return .none

             case .alert:
                 return .none
            case .setOnboardingDate(let date):
                state.onboardingDate = date
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
