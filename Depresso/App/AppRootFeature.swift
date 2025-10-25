import ComposableArchitecture
import SwiftUI
import SwiftData

@Reducer
struct AppRootFeature {
    @ObservableState
    struct State: Equatable {
        var authStatus: AuthStatus = .checking
        var currentUser: User?
        
        // Presentation state for login
        @Presents var loginState: LoginFeature.State?
        
        // AppFeature State (non-presented)
        var appFeatureState: AppFeature.State?
        
        var tokenRefreshState = TokenRefreshMiddleware.State()
        
        enum AuthStatus: Equatable {
            case checking, authenticated, unauthenticated
        }
        
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.authStatus == rhs.authStatus &&
            lhs.currentUser == rhs.currentUser &&
            lhs.loginState == rhs.loginState &&
            lhs.appFeatureState == rhs.appFeatureState &&
            lhs.tokenRefreshState == rhs.tokenRefreshState
        }
    }
    
    enum Action {
        case task
        case authCheckCompleted(User?)
        case logoutConfirmed
        case login(PresentationAction<LoginFeature.Action>)
        case appFeature(AppFeature.Action)
        case tokenRefresh(TokenRefreshMiddleware.Action)
        case handleAPIError(Error)
    }
    
    @Dependency(\.authClient) var authClient
    
    var body: some ReducerOf<Self> {
        Scope(state: \.tokenRefreshState, action: \.tokenRefresh) {
            TokenRefreshMiddleware()
        }
        
        Reduce { state, action in
            switch action {
            case .task:
                guard state.authStatus == .checking else { return .none }
                return .run { send in
                    let user = try? await authClient.getCurrentUser()
                    await send(.authCheckCompleted(user))
                }
                
            case .authCheckCompleted(let user):
                state.currentUser = user
                if let user = user {
                    state.authStatus = .authenticated
                    state.loginState = nil
                    if state.appFeatureState == nil {
                        state.appFeatureState = AppFeature.State()
                        state.appFeatureState?.settingsState.hasGrantedResearchConsent = user.hasGrantedResearchConsent
                    }
                } else {
                    state.authStatus = .unauthenticated
                    state.appFeatureState = nil
                    if state.loginState == nil {
                        state.loginState = LoginFeature.State()
                    }
                }
                return .none
                
            case .login(.presented(.delegate(.loginSuccessful(let response)))):
                state.currentUser = response.user
                state.authStatus = .authenticated
                state.loginState = nil
                state.appFeatureState = AppFeature.State()
                state.appFeatureState?.settingsState.hasGrantedResearchConsent = response.user.hasGrantedResearchConsent
                return .none
                
            case .login(.dismiss):
                if state.authStatus == .unauthenticated {
                    state.loginState = LoginFeature.State()
                }
                return .none
                
            case .appFeature(.settingsDelegate(.logout)):
                return .send(.logoutConfirmed)
                
            case .logoutConfirmed:
                state.authStatus = .unauthenticated
                state.currentUser = nil
                state.appFeatureState = nil
                state.loginState = LoginFeature.State()
                return .run { _ in
                    try? await authClient.logout()
                }
                
            case .handleAPIError(let error):
                let isTokenExpired = (error as? AuthError == .tokenExpired)
                if isTokenExpired {
                    return .send(.tokenRefresh(.tokenExpired))
                }
                print("AppRoot encountered non-token API Error: \(error)")
                return .none
                
            case .tokenRefresh(.delegate(.tokenRefreshed(let user))):
                state.currentUser = user
                state.appFeatureState?.settingsState.hasGrantedResearchConsent = user.hasGrantedResearchConsent
                return .none
                
            case .tokenRefresh(.delegate(.refreshFailed)):
                return .send(.logoutConfirmed)
                
                // ignore other scoped actions
            case .login, .appFeature, .tokenRefresh:
                return .none
            }
        }
        // Presentation scoping for login
        .ifLet(\.$loginState, action: \.login) {
            LoginFeature()
        }
        // Non-presented scoping for appFeature
        .ifLet(\.appFeatureState, action: \.appFeature) {
            AppFeature()
        }
    }
}

// MARK: - AppRootView
struct AppRootView: View {
    let store: StoreOf<AppRootFeature>
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            Group {
                switch viewStore.authStatus {
                case .checking:
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Loading...")
                            .foregroundStyle(.secondary)
                    }
                    
                case .authenticated:
                    // Show app when appFeatureState exists
                    IfLetStore(
                        self.store.scope(state: \.appFeatureState, action: AppRootFeature.Action.appFeature)
                    ) { appStore in
                        ContentView(store: appStore)
                            .environment(\.currentUser, viewStore.currentUser)
                    } else: {
                        ProgressView("Initializing App...")
                    }
                    
                case .unauthenticated:
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Present the login sheet using IfLetStore
                        .overlay {
                            IfLetStore(
                                self.store.scope(state: \.$loginState, action: AppRootFeature.Action.login)
                            ) { loginStore in
                                // Use an invisible button to trigger sheet presentation or use sheet attaching to the parent
                                LoginView(store: loginStore)
                                    .interactiveDismissDisabled()
                            } else: {
                                // Not presented — but we want to make sure login is created
                                EmptyView()
                            }
                        }
                }
            }
            .task {
                await viewStore.send(.task).finish()
            }
        }
    }
}
