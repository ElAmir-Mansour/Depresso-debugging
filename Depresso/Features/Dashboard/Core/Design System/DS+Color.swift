//
//  DS+Color.swift
//  Depresso
//
//  Created by ElAmir Mansour on 03/10/2025.
//
// In Core/DesignSystem/DS+Color.swift
import SwiftUI

// Define a namespace for our design system
enum DesignSystem { }

extension Color {
    /// The Design System's colors.
    static let ds = DSColor()
}

struct DSColor {
    let backgroundPrimary = Color("BackgroundPrimary")
    let textPrimary = Color("TextPrimary")
    let accent = Color("Accent")
}
