import Foundation
import ComposableArchitecture

@Reducer
struct TokenRefreshMiddleware {
    @ObservableState
    struct State: Equatable {
        var isRefreshing: Bool = false
        var lastRefreshAttempt: Date?
    }
    
    enum Action {
        case tokenExpired
        case refreshToken
        case tokenRefreshed(Result<AuthResponse, Error>)
        case delegate(Delegate)
        
        enum Delegate {
            case tokenRefreshed(User)
            case refreshFailed
        }
    }
    
    @Dependency(\.authClient) var authClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .tokenExpired:
                guard !state.isRefreshing else { return .none }
                
                if let lastAttempt = state.lastRefreshAttempt,
                   Date().timeIntervalSince(lastAttempt) < 5 {
                    return .none
                }
                
                return .send(.refreshToken)
                
            case .refreshToken:
                state.isRefreshing = true
                state.lastRefreshAttempt = Date()
                
                return .run { send in
                    await send(.tokenRefreshed(
                        Result { try await authClient.refreshToken() }
                    ))
                }
                
            case .tokenRefreshed(.success(let response)):
                state.isRefreshing = false
                return .send(.delegate(.tokenRefreshed(response.user)))
                
            case .tokenRefreshed(.failure):
                state.isRefreshing = false
                return .send(.delegate(.refreshFailed))
                
            case .delegate:
                return .none
            }
        }
    }
}
