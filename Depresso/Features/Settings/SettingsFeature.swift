import ComposableArchitecture
import SwiftUI

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var hasGrantedResearchConsent: Bool = false
        var showingLogoutConfirmation: Bool = false
        var showingConsentRevoke: Bool = false
        @Presents var consentSheet: ResearchConsentFeature.State?
    }

    enum Action {
        case logoutTapped
        case confirmLogout
        case cancelLogout
        case revokeConsentTapped
        case confirmRevokeConsent
        case cancelRevokeConsent
        case grantConsentTapped
        case consentSheet(PresentationAction<ResearchConsentFeature.Action>)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case logout
        }
    }

    @Dependency(\.authClient) var authClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            // MARK: Logout flow
            case .logoutTapped:
                state.showingLogoutConfirmation = true
                return .none

            case .confirmLogout:
                state.showingLogoutConfirmation = false
                return .send(.delegate(.logout))

            case .cancelLogout:
                state.showingLogoutConfirmation = false
                return .none

            // MARK: Consent revoke flow
            case .revokeConsentTapped:
                state.showingConsentRevoke = true
                return .none

            case .confirmRevokeConsent:
                state.showingConsentRevoke = false
                state.hasGrantedResearchConsent = false
                return .run { _ in
                    try? await authClient.revokeResearchConsent()
                    print("✅ Consent revoked")
                }

            case .cancelRevokeConsent:
                state.showingConsentRevoke = false
                return .none

            // MARK: Grant consent flow
            case .grantConsentTapped:
                state.consentSheet = ResearchConsentFeature.State()
                return .none

            // MARK: Sheet events
            case .consentSheet(.presented(.delegate(.consentGranted))):
                state.hasGrantedResearchConsent = true
                state.consentSheet = nil
                return .none

            case .consentSheet(.dismiss):
                state.consentSheet = nil
                return .none

            case .consentSheet:
                return .none

            case .delegate:
                return .none
            }
        }
        // ✅ Correct .ifLet binding for TCA 1.22
        .ifLet(\.$consentSheet, action: \.consentSheet) {
            ResearchConsentFeature()
        }
    }
}

// MARK: - View

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @Environment(\.currentUser) var currentUser

    var body: some View {
        List {
            accountSection
            researchSection
            logoutSection
        }
        .navigationTitle("Settings")

        // MARK: Logout Confirmation
        .confirmationDialog(
            "Log Out",
            isPresented: store.binding(\.$showingLogoutConfirmation), // ✅ FIXED BINDING
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) { store.send(.confirmLogout) }
            Button("Cancel", role: .cancel) { store.send(.cancelLogout) }
        } message: {
            Text("Are you sure you want to log out?")
        }

        // MARK: Revoke Consent Dialog
        .confirmationDialog(
            "Withdraw Consent",
            isPresented: store.binding(\.$showingConsentRevoke), // ✅ FIXED BINDING
            titleVisibility: .visible
        ) {
            Button("Withdraw", role: .destructive) { store.send(.confirmRevokeConsent) }
            Button("Cancel", role: .cancel) { store.send(.cancelRevokeConsent) }
        } message: {
            Text("This will stop collection of behavioral metrics for research.")
        }

        // MARK: Consent Sheet
        .sheet(
            item: $store.scope(state: \.$consentSheet, action: \.consentSheet) // ✅ FIXED SCOPE
        ) { consentStore in
            ResearchConsentView(store: consentStore)
        }
    }

    // MARK: - Account Section
    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if let user = currentUser {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(user.email)
                            .font(.headline)
                        Text("Member since \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Loading account details...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Research Section
    @ViewBuilder
    private var researchSection: some View {
        Section {
            if store.hasGrantedResearchConsent {
                grantedConsentView
            } else {
                noConsentView
            }
        } header: {
            Text("Research")
        } footer: {
            Text("Your participation is voluntary and you can withdraw at any time.")
        }
    }

    private var grantedConsentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Research Participation").font(.headline)
                    Text("Contributing to mental health research")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Button("Withdraw Consent", role: .destructive) {
                store.send(.revokeConsentTapped)
            }
        }
    }

    private var noConsentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Help Mental Health Research").font(.headline)
            Text("Participate in research to improve mental wellness tools")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Learn More & Consent") {
                store.send(.grantConsentTapped)
            }
            .foregroundStyle(.blue)
        }
    }

    // MARK: - Logout Section
    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                store.send(.logoutTapped)
            } label: {
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView(
            store: Store(
                initialState: SettingsFeature.State()
            ) {
                SettingsFeature()
            }
        )
        .environment(\.currentUser, User.mock)
    }
}
