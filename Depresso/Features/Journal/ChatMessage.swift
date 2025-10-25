// In Features/Journal/ChatMessage.swift
import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique)
    var id: UUID
    var timestamp: Date
    var content: String
    var isFromCurrentUser: Bool

    init(id: UUID = UUID(), timestamp: Date = .now, content: String, isFromCurrentUser: Bool) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
        self.isFromCurrentUser = isFromCurrentUser
    }
}
