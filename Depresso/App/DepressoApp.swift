import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct DepressoApp: App {
    let store = Store(initialState: AppRootFeature.State()) {
        AppRootFeature()
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
                .modelContainer(for: [
                    ChatMessage.self,
                    WellnessTask.self,
                    CommunityPost.self
                ])
        }
    }
}
