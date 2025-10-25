import SwiftUI
import ComposableArchitecture
import SwiftData

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var journalState = AICompanionJournalFeature.State()
        var dashboardState = DashboardFeature.State()
        var communityState = CommunityFeature.State()
        var supportState = SupportFeature.State()
        var settingsState = SettingsFeature.State()
        
        @Presents var onboardingState: OnboardingFeature.State?
        var hasCompletedOnboarding: Bool = false
        
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.hasCompletedOnboarding == rhs.hasCompletedOnboarding &&
            (lhs.onboardingState == nil) == (rhs.onboardingState == nil) &&
            lhs.journalState == rhs.journalState &&
            lhs.dashboardState == rhs.dashboardState &&
            lhs.communityState == rhs.communityState &&
            lhs.supportState == rhs.supportState &&
            lhs.settingsState == rhs.settingsState
        }
    }
    
    enum Action {
        case journal(AICompanionJournalFeature.Action)
        case dashboard(DashboardFeature.Action)
        case community(CommunityFeature.Action)
        case support(SupportFeature.Action)
        case settings(SettingsFeature.Action)
        case onboarding(PresentationAction<OnboardingFeature.Action>)
        case task
        case checkForOnboarding
        case settingsDelegate(SettingsFeature.Action.Delegate)
        case updateOnboardingDate(Date)

    }
    
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    
    var body: some Reducer<State, Action> {
        Scope(state: \.journalState, action: \.journal) {
            AICompanionJournalFeature()
        }
        Scope(state: \.dashboardState, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.communityState, action: \.community) {
            CommunityFeature()
        }
        Scope(state: \.supportState, action: \.support) {
            SupportFeature()
        }
        Scope(state: \.settingsState, action: \.settings) {
            SettingsFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .task:
                return .send(.checkForOnboarding)
                
            case .checkForOnboarding:
                if !state.hasCompletedOnboarding {
                    state.onboardingState = OnboardingFeature.State()
                } else {
                    return .run { [userDefaultsClient] send in
                        if let date = try? await userDefaultsClient.getOnboardingDate() {
                            await send(.updateOnboardingDate(date))
                        }
                    }
                }
                return .none
                
            case .onboarding(.presented(.delegate(.onboardingCompleted))):
                state.hasCompletedOnboarding = true
                state.onboardingState = nil
                
                return .run { [userDefaultsClient] send in
                    if let date = try? await userDefaultsClient.getOnboardingDate() {
                        await send(.updateOnboardingDate(date))
                    }
                }
                
            case .updateOnboardingDate(let date):
                state.journalState.onboardingDate = date
                return .none
                
            case .settings(.delegate(.logout)):
                print("📤 Received logout signal from Settings")
                return .none
                
            case .settingsDelegate(.logout):
                print("📤 AppFeature handling settingsDelegate logout")
                return .none
                
            case .journal, .dashboard, .community, .support, .settings, .onboarding:
                return .none
            }
        }
        .ifLet(\.$onboardingState, action: \.onboarding) {
            OnboardingFeature()
        }
    }

}

struct ContentView: View {
    @Bindable var store: StoreOf<AppFeature> // <-- FIX: Use @Bindable
    @Environment(\.currentUser) var currentUser
    
    var body: some View {
        TabView {
            DashboardView(store: store.scope(state: \.dashboardState, action: \.dashboard))
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
            
            JournalView(store: store.scope(state: \.journalState, action: \.journal))
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
            
            CommunityView(store: store.scope(state: \.communityState, action: \.community))
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
            
            SupportView(store: store.scope(state: \.supportState, action: \.support))
                .tabItem {
                    Label("Support", systemImage: "heart.fill")
                }
            
            NavigationStack {
                SettingsView(store: store.scope(state: \.settingsState, action: \.settings))
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        // This will now compile because $store exists
        .sheet(item: $store.scope(state: \.onboardingState, action: \.onboarding)) { onboardingStore in
            OnboardingView(store: onboardingStore)
                .interactiveDismissDisabled()
        }
        .task {
            await store.send(.task).finish()
        }
    }
}

// MARK: - Preview
#Preview {
    let container = try! ModelContainer(
        for: ChatMessage.self,
             WellnessTask.self,
             CommunityPost.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    
    return ContentView(
        store: Store(
            initialState: AppFeature.State(hasCompletedOnboarding: false)
        ) {
            AppFeature()
        } withDependencies: {
            $0.userDefaultsClient = .previewValue
            $0.modelContext = ModelContextBox(context)
            $0.aiClient = .previewValue
            $0.healthClient = .previewValue
            $0.motionClient = .previewValue
            $0.dataSubmissionClient = .previewValue
            $0.authClient = .previewValue
            $0.currentUser = User.mock
        }
    )
    .modelContainer(container)
}

// MARK: - User Mock Extension
extension User {
    static var mock: User {
        User(
            id: "previewUser",
            email: "preview@example.com",
            createdAt: Date(),
            hasGrantedResearchConsent: true,
            researchParticipantId: "previewResearchId"
        )
    }
}
