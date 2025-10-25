//
//  DailyAssessmentView.swift
//  Depresso
//
//  Created by ElAmir Mansour on 24/10/2025.
//

// In Features/Dashboard/DailyAssessmentView.swift
import SwiftUI
import ComposableArchitecture

struct DailyAssessmentView: View {
    @Bindable var store: StoreOf<DailyAssessmentFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.large) {
                Text("Daily Check-in")
                    .font(.ds.title)
                    .padding(.horizontal)

                ProgressView(value: store.progress)
                    .padding(.horizontal)
                    .tint(.ds.accent)

                let currentQuestion = store.questions[store.currentQuestionIndex]
                VStack {
                    Text("Over the last 24 hours, how often bothered by:") // Adjusted timeframe
                        .font(.ds.caption)
                        .foregroundStyle(.secondary)
                    Text(currentQuestion.text)
                        .font(.ds.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(minHeight: 150, alignment: .center)

                VStack(spacing: DesignSystem.Spacing.medium) {
                    ForEach(PHQ8.Answer.allCases, id: \.self) { answer in
                        Button {
                            store.send(.answerQuestion(index: store.currentQuestionIndex, answer: answer))
                        } label: {
                            Text(answer.description)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    store.questions[store.currentQuestionIndex].answer == answer ?
                                        Color.ds.accent : Color(UIColor.secondarySystemGroupedBackground)
                                )
                                .foregroundStyle(
                                    store.questions[store.currentQuestionIndex].answer == answer ?
                                        .white : .primary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                HStack {
                    if store.currentQuestionIndex > 0 {
                        Button("Back") { store.send(.backButtonTapped) }
                           .padding()
                    }
                    Spacer()
                    Button(store.currentQuestionIndex < store.questions.count - 1 ? "Next" : "Finish") {
                        store.send(.nextButtonTapped)
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .tint(.ds.accent)
                    .disabled(!store.isNextButtonEnabled)
                }
                .padding()
            }
            .animation(.default, value: store.currentQuestionIndex)
            .toolbar {
                 ToolbarItem(placement: .navigationBarLeading) {
                     Button("Cancel") { store.send(.delegate(.cancel)) }
                 }
            }
        }
    }
}

#Preview {
    DailyAssessmentView(
        store: Store(initialState: DailyAssessmentFeature.State()) {
            DailyAssessmentFeature()
        }
    )
}
