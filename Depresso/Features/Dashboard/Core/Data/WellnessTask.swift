//
//  WellnessTask.swift
//  Depresso
//
//  Created by ElAmir Mansour on 03/10/2025.
//

// In Core/Data/WellnessTask.swift
import Foundation
import SwiftData

@Model
final class WellnessTask {
    @Attribute(.unique)
    var id: UUID
    var title: String
    var isCompleted: Bool
    var creationDate: Date

    init(title: String, isCompleted: Bool = false, creationDate: Date = .now) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.creationDate = creationDate
    }
}
