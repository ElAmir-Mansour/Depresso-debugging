//
//  RegisterFeature.swift
//  Depresso
//
//  Created by ElAmir Mansour on 25/10/2025.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct RegisterFeature {
    @ObservableState
    struct State: Equatable {
        var email: String = ""
        var password: String = ""
        var confirmPassword: String = ""
        var isLoading: Bool = false
        var errorMessage: String?
        var showingConsent: Bool = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case registerButtonTapped
        case registerResponse(Result<AuthResponse, Error>)
        case dismissError
        case dismiss
        case delegate(Delegate)

        enum Delegate: Equatable {
            case registrationSuccessful(AuthResponse)
        }
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .registerButtonTapped:
                if state.password != state.confirmPassword {
                    state.errorMessage = "Passwords do not match"
                    return .none
                }
                if state.password.count < 8 {
                    state.errorMessage = "Password must be at least 8 characters"
                    return .none
                }
                if !state.email.contains("@") {
                    state.errorMessage = "Please enter a valid email"
                    return .none
                }

                state.isLoading = true
                state.errorMessage = nil

                let request = RegisterRequest(
                    email: state.email.trimmingCharacters(in: .whitespaces),
                    password: state.password,
                    confirmPassword: state.confirmPassword
                )

                return .run { send in
                    await send(.registerResponse(
                        Result {
                            try await authClient.register(request)
                        }
                    ))
                }

            case .registerResponse(.success(let response)):
                state.isLoading = false
                return .send(.delegate(.registrationSuccessful(response)))

            case .registerResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .dismiss:
                return .run { _ in await dismiss() }

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Register View (unchanged)
struct RegisterView: View {
    @Bindable var store: StoreOf<RegisterFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("Create Account")
                            .font(.title.bold())

                        Text("Join Depresso to begin your mental wellness journey")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 16) {
                        TextField("Email", text: $store.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textFieldStyle(.roundedBorder)
                            .disabled(store.isLoading)

                        SecureField("Password", text: $store.password)
                            .textContentType(.newPassword)
                            .textFieldStyle(.roundedBorder)
                            .disabled(store.isLoading)

                        SecureField("Confirm Password", text: $store.confirmPassword)
                            .textContentType(.newPassword)
                            .textFieldStyle(.roundedBorder)
                            .disabled(store.isLoading)

                        VStack(alignment: .leading, spacing: 4) {
                            PasswordRequirement(
                                text: "At least 8 characters",
                                isMet: store.password.count >= 8
                            )
                            PasswordRequirement(
                                text: "Passwords match",
                                isMet: !store.password.isEmpty && store.password == store.confirmPassword
                            )
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)

                    if let errorMessage = store.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal)
                    }

                    Button {
                        store.send(.registerButtonTapped)
                    } label: {
                        HStack {
                            if store.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(
                        store.isLoading ||
                        store.email.isEmpty ||
                        store.password.isEmpty ||
                        store.confirmPassword.isEmpty
                    )
                    .padding(.horizontal)

                    Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.dismiss)
                    }
                }
            }
        }
    }
}

// MARK: - Password Requirement View (unchanged)
struct PasswordRequirement: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isMet ? .green : .gray)
            Text(text)
                .foregroundStyle(isMet ? .primary : .secondary)
        }
    }
}
