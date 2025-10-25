//
//  SupportModels.swift
//  Depresso
//
//  Created by ElAmir Mansour on 24/10/2025.
//

// In Features/Support/SupportModels.swift
import Foundation

// Represents a helpful article, website, or organization
struct SupportResource: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let url: URL
    let iconName: String // SF Symbol name for visual aid
}

// Represents an emergency contact or helpline
struct Hotline: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let phoneNumber: String
    let description: String? // Optional extra info
    let iconName: String // SF Symbol name
}
