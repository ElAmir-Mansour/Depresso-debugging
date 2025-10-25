import ComposableArchitecture
import SwiftUI

@Reducer
struct ResearchConsentFeature {
    @ObservableState
    struct State: Equatable {
        var hasReadConsent: Bool = false
        var agreedToConsent: Bool = false
        var isSubmitting: Bool = false
        var errorMessage: String?
        let consentVersion: String = "1.0"
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case grantConsentTapped
        case declineConsentTapped
        case consentResponse(Result<ResearchConsentResponse, Error>)
        case dismissError
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case consentGranted
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
                
            case .grantConsentTapped:
                guard state.hasReadConsent && state.agreedToConsent else {
                    state.errorMessage = "Please read and agree to the consent terms"
                    return .none
                }
                
                state.isSubmitting = true
                state.errorMessage = nil
                
                let request = ResearchConsentRequest(
                    consents: true,
                    consentVersion: state.consentVersion
                )
                
                return .run { send in
                    await send(.consentResponse(
                        Result { try await authClient.grantResearchConsent(request) }
                    ))
                }
                
            case .declineConsentTapped:
                return .run { _ in
                    await dismiss()
                }
                
            case .consentResponse(.success):
                state.isSubmitting = false
                return .run { send in
                    await send(.delegate(.consentGranted))
                    await dismiss()
                }
                
            case .consentResponse(.failure(let error)):
                state.isSubmitting = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .dismissError:
                state.errorMessage = nil
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Research Consent View
struct ResearchConsentView: View {
    @Bindable var store: StoreOf<ResearchConsentFeature>
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Research Participation Consent")
                        .font(.title2.bold())
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        ConsentSection(
                            title: "Purpose",
                            content: "Help improve mental health research by sharing anonymous behavioral data."
                        )
                        
                        ConsentSection(
                            title: "What We Collect",
                            content: "Typing patterns, device motion, session duration. We do NOT collect your journal text."
                        )
                        
                        ConsentSection(
                            title: "Your Rights",
                            content: "Participation is voluntary. You can withdraw at any time from Settings."
                        )
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: $store.hasReadConsent) {
                            Text("I have read and understood the information above")
                                .font(.subheadline)
                        }
                        
                        Toggle(isOn: $store.agreedToConsent) {
                            Text("I voluntarily agree to participate in this research")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    if let error = store.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 12) {
                        Button {
                            store.send(.grantConsentTapped)
                        } label: {
                            if store.isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("I Consent to Participate")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(store.isSubmitting)
                        
                        Button {
                            store.send(.declineConsentTapped)
                        } label: {
                            Text("Decline")
                                .foregroundStyle(.secondary)
                        }
                        .disabled(store.isSubmitting)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ConsentSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
