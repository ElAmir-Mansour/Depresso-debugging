// In Features/Support/SupportFeature.swift
import Foundation
import ComposableArchitecture

@Reducer
struct SupportFeature {
    @ObservableState
    struct State: Equatable {
        var resources: [SupportResource] = [
            // --- NEW: Links to Therapist Directories ---
            .init(title: "Shezlong",
                  description: "Online platform to find and book sessions with licensed therapists in Egypt.",
                  url: URL(string: "https://www.shezlong.com/en")!, // Verify URL
                  iconName: "magnifyingglass"),
            .init(title: "O7 Therapy",
                  description: "Another platform connecting users with mental health professionals in the region.",
                  url: URL(string: "https://o7therapy.com/")!, // Verify URL
                  iconName: "person.crop.circle.badge.questionmark"),
            // --- Existing Resources ---
            .init(title: "GSMHAT Website",
                  description: "Official information from the General Secretariat of Mental Health.",
                  url: URL(string: "http://www.gsmhat.gov.eg")!, // Verify URL
                  iconName: "network"),
            .init(title: "World Health Organization (WHO) - Depression",
                  description: "Global information on understanding depression.",
                  url: URL(string: "https://www.who.int/news-room/fact-sheets/detail/depression")!,
                  iconName: "book.closed"),
            .init(title: "Building Better Mental Health",
                  description: "General tips for improving mental wellness (HelpGuide).",
                  url: URL(string: "https://www.helpguide.org/articles/healthy-living/building-better-mental-health.htm")!,
                  iconName: "heart.text.square")
            // Add other verified NGOs or resources here
        ]
        
        var hotlines: [Hotline] = [
             .init(name: "Ministry of Health Mental Health Hotline", phoneNumber: "16328", description: "General Secretariat of Mental Health and Addiction Treatment (GSMHAT) hotline.", iconName: "phone.fill"),
             .init(name: "Emergency Police", phoneNumber: "122", description: "General emergency number.", iconName: "exclamationmark.bubble.fill"),
             .init(name: "Ambulance", phoneNumber: "123", description: "For medical emergencies.", iconName: "cross.fill")
             // Add other verified hotlines
        ]
    }
    
    enum Action { /* No actions needed yet */ }
    
    // Use MainActor isolation for safe context access if needed later
    @MainActor
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            return .none
        }
    }
}
