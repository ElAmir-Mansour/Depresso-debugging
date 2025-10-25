// In Features/Journal/JournalView.swift
import SwiftUI
import ComposableArchitecture
import SwiftData

struct JournalView: View {
    // Use @Bindable for TCA Swift Observation
    @Bindable var store: StoreOf<AICompanionJournalFeature>
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) { // Use spacing 0 for tighter layout
                ScrollViewReader { scrollViewProxy in
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.medium) { // Use LazyVStack for performance
                            ForEach(store.messages) { message in
                                MessageBubble(message: message)
                                   .id(message.id) // ID for scrolling
                                   // Animate appearance
                                   .transition(.scale(scale: 0.95, anchor: message.isFromCurrentUser ? .bottomTrailing : .bottomLeading).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.top, DesignSystem.Spacing.small)
                        // Add bottom padding to prevent overlap with input area
                        .padding(.bottom, DesignSystem.Spacing.medium)
                    }
                    .id("journalScrollView") // Stable ID for ScrollView
                    .onTapGesture {
                        isTextFieldFocused = false // Dismiss keyboard on tap
                    }
                    .onChange(of: store.messages.count) { // Scroll to bottom on new message
                        scrollToBottom(proxy: scrollViewProxy, animated: true)
                    }
                    .onAppear { // Scroll to bottom when view appears
                        scrollToBottom(proxy: scrollViewProxy, animated: false)
                    }
                }

                // Input Area
                VStack(spacing: 8) { // Group submission status and input field
                    // Submission Status/Error Display (Added from Snippet)
                    if store.isSubmittingBehavioralData {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7) // Smaller progress view
                            Text("Saving research data...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer() // Push to leading edge
                        }
                        .padding(.horizontal)
                        .padding(.top, 4) // Add slight top padding
                    } else if let error = store.behavioralDataSubmissionError {
                        HStack(alignment: .top) { // Align items top for multi-line errors
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                                .padding(.top, 2) // Align icon better with text

                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2) // Limit error message lines

                            Spacer()

                            Button {
                                store.send(.dismissSubmissionError)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                     .foregroundStyle(.gray)
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }

                    // Text Input Field and Send Button
                    HStack(alignment: .bottom, spacing: 12) { // Align items to bottom
                        // Use a custom TextEditor-like field for multi-line input if needed
                        TextField("How are you feeling...", text: $store.textInput, axis: .vertical)
                            .lineLimit(1...5) // Allow up to 5 lines
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            // .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) // Apply background instead of clipShape
                            .focused($isTextFieldFocused)
                            // Detect backspace
                            .onChange(of: store.textInput) { oldValue, newValue in
                                if newValue.count < oldValue.count {
                                    store.send(.userDidBackspace)
                                }
                            }

                        Button {
                            store.send(.sendButtonTapped)
                        } label: {
                            Image(systemName: "arrow.up.circle.fill") // Changed icon slightly
                                .font(.title2) // Slightly larger icon
                                .foregroundStyle(store.textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color.ds.accent) // Use accent color
                        }
                        .disabled(store.textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSendingMessage) // Disable while sending
                    }
                     .padding(.horizontal)
                     .padding(.top, store.isSubmittingBehavioralData || store.behavioralDataSubmissionError != nil ? 0 : 8) // Adjust top padding based on status bar
                     .padding(.bottom, 8) // Consistent bottom padding

                }
                .background(.regularMaterial) // Background for the whole input area
                // .clipShape(RoundedRectangle(cornerRadius: 20)) // Maybe remove this if background covers it
                // .shadow(radius: 1) // Optional shadow
            }
            .background(Color.ds.backgroundPrimary) // Background for the main VStack
            .navigationTitle("Mindful Moments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { // Toolbar for keyboard dismissal
                ToolbarItemGroup(placement: .keyboard) {
                     Spacer() // Pushes button to the right
                     Button("Done") {
                         isTextFieldFocused = false
                     }
                 }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .task { // TCA's recommended way to run async work on appear
                await store.send(.task).finish()
            }
            .onDisappear { // Send disappear action
                 store.send(.onDisappear)
             }
        }
    }

    // Helper function to scroll to bottom
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMessageId = store.messages.last?.id else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.smooth) {
                    proxy.scrollTo(lastMessageId, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastMessageId, anchor: .bottom)
            }
        }
    }
}
