//
//  JournalEntry.swift
//  Depresso
//
//  Created by ElAmir Mansour on 03/10/2025.
//

// In Core/Data/JournalEntry.swift
import Foundation
import SwiftData

@Model
final class JournalEntry {
    @Attribute(.unique)
    var id: UUID
    var timestamp: Date
    var content: String

    init(id: UUID = UUID(), timestamp: Date = Date(), content: String) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
    }
}
