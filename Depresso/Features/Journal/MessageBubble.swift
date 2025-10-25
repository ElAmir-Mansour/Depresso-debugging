import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromCurrentUser { Spacer(minLength: 40) }

            // MARK: - Text Bubble
            Group {
                if message.isFromCurrentUser {
                    Text(message.content)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.ds.accent.opacity(0.9),
                                    Color.ds.accent.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Text(message.content)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .foregroundStyle(Color.primary)
                        .background(Color(UIColor.systemGray6))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7,
                   alignment: message.isFromCurrentUser ? .trailing : .leading)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .transition(.move(edge: message.isFromCurrentUser ? .trailing : .leading)
                        .combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.8),
                       value: message.content)

            if !message.isFromCurrentUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}

#Preview {
    VStack(spacing: 8) {
        MessageBubble(message: ChatMessage(content: "User message with gradient background.", isFromCurrentUser: true))
        MessageBubble(message: ChatMessage(content: "AI reply bubble with solid gray color.", isFromCurrentUser: false))
        MessageBubble(message: ChatMessage(content: "Another long message that wraps beautifully and demonstrates consistent padding.", isFromCurrentUser: false))
    }
    .padding()
    .background(Color.ds.backgroundPrimary)
}
