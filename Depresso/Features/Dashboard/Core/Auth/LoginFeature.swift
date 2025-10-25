//
//  LoginFeature.swift
//  Depresso
//
//  Created by ElAmir Mansour on 2025-10-25.
//
import SwiftUI
import ComposableArchitecture

@Reducer
struct LoginFeature {
    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var email: String = ""
        var password: String = ""
        var isLoading: Bool = false
        var errorMessage: String?
        @Presents var register: RegisterFeature.State?
    }

    // MARK: - Action
    enum Action {
        case emailChanged(String)
        case passwordChanged(String)
        case loginTapped
        case loginResponse(Result<AuthResponse, Error>)
        case registerTapped
        case register(PresentationAction<RegisterFeature.Action>)
        case dismissError
        case delegate(Delegate)

        enum Delegate: Equatable {
            case loginSuccessful(AuthResponse)
        }
    }

    // MARK: - Dependencies
    @Dependency(\.authClient) var authClient

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .emailChanged(email):
                state.email = email
                return .none

            case let .passwordChanged(password):
                state.password = password
                return .none

            case .loginTapped:
                state.isLoading = true
                state.errorMessage = nil
                let request = LoginRequest(
                    email: state.email.trimmingCharacters(in: .whitespaces),
                    password: state.password
                )

                return .run { [request, authClient = self.authClient] send in
                    await send(.loginResponse(
                        Result {
                            try await authClient.login(request)
                        }
                    ))
                }

            case let .loginResponse(.success(response)):
                state.isLoading = false
                return .send(.delegate(.loginSuccessful(response)))

            case let .loginResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .registerTapped:
                state.register = RegisterFeature.State()
                return .none

            case .register(.presented(.delegate(.registrationSuccessful(let response)))):
                 state.register = nil
                 return .send(.delegate(.loginSuccessful(response)))

            case .register(.dismiss):
                state.register = nil
                return .none

            case .register:
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$register, action: \.register) {
            RegisterFeature()
        }
    }
}

// MARK: - View (unchanged)
struct LoginView: View {
    let store: StoreOf<LoginFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                VStack(spacing: 24) {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.blue.gradient)
                        Text("Welcome to Depresso")
                            .font(.title.bold())
                        Text("Your mental wellness companion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(spacing: 16) {
                        TextField(
                            "Email",
                            text: Binding(
                                get: { viewStore.email },
                                set: { viewStore.send(.emailChanged($0)) }
                            )
                        )
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewStore.isLoading)

                        SecureField(
                            "Password",
                            text: Binding(
                                get: { viewStore.password },
                                set: { viewStore.send(.passwordChanged($0)) }
                            )
                        )
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewStore.isLoading)
                    }
                    .padding(.horizontal)

                    if let error = viewStore.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Button {
                        viewStore.send(.loginTapped)
                    } label: {
                        if viewStore.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Log In").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .disabled(viewStore.isLoading || viewStore.email.isEmpty || viewStore.password.isEmpty)

                    Button {
                        viewStore.send(.registerTapped)
                    } label: {
                        Text("Don't have an account? **Sign Up**")
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .sheet(
                    store: store.scope(
                        state: \.$register,
                        action: LoginFeature.Action.register
                    )
                ) { registerStore in
                    RegisterView(store: registerStore)
                }
            }
        }
    }
}
