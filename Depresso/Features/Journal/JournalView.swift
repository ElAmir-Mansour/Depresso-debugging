// Depresso/Features/Journal/JournalView.swift

import SwiftUI
import ComposableArchitecture

struct JournalView: View {
    let store: StoreOf<JournalFeature>
    
    var body: some View {
        // ✅ CORRECT - Observe only what this view needs
        WithPerceptionTracking {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // Messages list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if store.isLoading {
                                LoadingIndicator()
                            }
                        }
                        .padding()
                    }
                    
                    // Input area
                    MessageInputView(
                        text: $store.currentInput.sending(\.textChanged),
                        onSend: { store.send(.sendMessage) }
                    )
                }
                .onAppear {
                    store.send(.viewAppeared)
                    store.send(.trackingStarted)
                }
                .onChange(of: store.messages.count) { _, _ in
                    if let lastMessage = store.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: JournalFeature.ChatMessageValue
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser { Spacer() }
        }
    }
}

struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type your thoughts...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...6)
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct LoadingIndicator: View {
    var body: some View {
        HStack {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Thinking...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
