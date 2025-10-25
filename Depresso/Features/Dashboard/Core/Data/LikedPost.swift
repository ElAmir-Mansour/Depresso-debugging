//
//  LikedPost.swift
//  Depresso
//
//  Created by ElAmir Mansour on 25/10/2025.
//

import Foundation
import SwiftData

@Model
final class LikedPost {
    @Attribute(.unique) var id: UUID

    init(id: UUID) {
        self.id = id
    }
}
