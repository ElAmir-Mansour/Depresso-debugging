//
//  DS+Typography.swift
//  Depresso
//
//  Created by ElAmir Mansour on 03/10/2025.
//

// In Core/DesignSystem/DS+Typography.swift
import SwiftUI

extension Font {
    /// The Design System's fonts.
    static let ds = DSTypography()
}

struct DSTypography {
    let title = Font.largeTitle.weight(.bold)
    let headline = Font.headline.weight(.semibold)
    let body = Font.body
    let caption = Font.caption
}
