// In Features/Onboarding/OnboardingView.swift
import SwiftUI
import ComposableArchitecture
import Charts // ✅ ADD: Import the Charts framework

struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack {
                if viewStore.isCompleted {
                    analysisView(viewStore)
                } else {
                    questionView(viewStore)
                }
            }
            .animation(.default, value: viewStore.currentQuestionIndex)
            .animation(.default, value: viewStore.isCompleted)
        }
    }

    // ... (questionView remains the same)
    @ViewBuilder
    private func questionView(_ viewStore: ViewStoreOf<OnboardingFeature>) -> some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Text("How have you been feeling?")
                .font(.ds.title)
                .padding(.horizontal)

            ProgressView(value: viewStore.progress)
                .padding(.horizontal)
                .tint(.ds.accent)

            let currentQuestion = viewStore.questions[viewStore.currentQuestionIndex]
            VStack {
                Text("Over the last 2 weeks, how often have you been bothered by:")
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
                        viewStore.send(.answerQuestion(index: viewStore.currentQuestionIndex, answer: answer))
                    } label: {
                        Text(answer.description)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                viewStore.questions[viewStore.currentQuestionIndex].answer == answer ?
                                    Color.ds.accent : Color(UIColor.secondarySystemGroupedBackground)
                            )
                            .foregroundStyle(
                                viewStore.questions[viewStore.currentQuestionIndex].answer == answer ?
                                    .white : .primary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            HStack {
                if viewStore.currentQuestionIndex > 0 {
                    Button("Back") {
                        viewStore.send(.backButtonTapped)
                    }
                    .padding()
                }

                Spacer()

                Button(viewStore.currentQuestionIndex < viewStore.questions.count - 1 ? "Next" : "Finish") {
                    viewStore.send(.nextButtonTapped)
                }
                .padding()
                .background(Color.ds.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .disabled(!viewStore.isNextButtonEnabled)
            }
            .padding()
        }
    }


    // ✅ --- NEW, REDESIGNED ANALYSIS VIEW ---
    @ViewBuilder
    private func analysisView(_ viewStore: ViewStoreOf<OnboardingFeature>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                Text("Your Results")
                    .font(.ds.title)

                // --- Gauge Chart ---
                VStack {
                    Chart {
                        // Background track for the gauge
                        SectorMark(
                            angle: .value("Severity", 24),
                            innerRadius: .ratio(0.6),
                            outerRadius: .ratio(1.0),
                            angularInset: 2
                        )
                        .foregroundStyle(Color(UIColor.systemGray5))
                        
                        // User's score mark
                        SectorMark(
                            angle: .value("Score", viewStore.finalScore),
                            innerRadius: .ratio(0.6),
                            outerRadius: .ratio(1.0),
                            angularInset: 2
                        )
                        .foregroundStyle(Color.ds.accent.gradient)
                        .cornerRadius(8)
                    }
                    .chartAngleSelection(value: .constant(12)) // Disables interaction
                    .frame(height: 200)
                    .chartYAxis(.hidden)
                    .overlay {
                        VStack {
                            Text("\(viewStore.finalScore)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                            Text(viewStore.severity)
                                .font(.ds.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("PHQ-8 Score (out of 24)")
                        .font(.ds.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, DesignSystem.Spacing.small)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // --- AI Analysis Section ---
                if viewStore.isLoadingAnalysis {
                    VStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
                        ProgressView()
                        Text("Preparing your personalized analysis...")
                            .font(.ds.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if let analysis = viewStore.analysis {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        Text("What This Means")
                            .font(.ds.headline)
                        Text(analysis)
                            .font(.ds.body)
                    }
                } else {
                    // Button to trigger the analysis
                    Button("Get My Analysis") {
                        viewStore.send(.getAnalysisButtonTapped)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.ds.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }

                Spacer()

                if viewStore.analysis != nil {
                    Button("Get Started") {
                        viewStore.send(.delegate(.onboardingCompleted))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.ds.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }
            .padding()
        }
        .onAppear {
            // If the score is calculated but analysis isn't loaded, fetch it.
            if viewStore.finalScore > 0 && viewStore.analysis == nil && !viewStore.isLoadingAnalysis {
                viewStore.send(.getAnalysisButtonTapped)
            }
        }
    }
}
