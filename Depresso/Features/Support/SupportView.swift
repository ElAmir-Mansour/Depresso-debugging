// In Features/Support/SupportView.swift
import SwiftUI
import ComposableArchitecture

struct SupportView: View {
    let store: StoreOf<SupportFeature>

    var body: some View {
        NavigationStack {
            // Use WithViewStore to observe the state
            WithViewStore(self.store, observe: { $0 }) { viewStore in
                List {
                    // Section for Emergency Hotlines
                    Section("Immediate Help") {
                        ForEach(viewStore.hotlines) { hotline in
                            HotlineRowView(hotline: hotline)
                        }
                    }
                    
                    // Section for Resources
                    Section("Resources & Information") {
                        ForEach(viewStore.resources) { resource in
                            ResourceRowView(resource: resource)
                        }
                    }
                }
                .navigationTitle("Support & Resources")
            }
        }
    }
}

// View for displaying a single hotline
struct HotlineRowView: View {
    let hotline: Hotline
    
    var body: some View {
        HStack {
            Image(systemName: hotline.iconName)
                .foregroundStyle(Color.ds.accent)
                .frame(width: 30) // Align icons
            
            VStack(alignment: .leading) {
                Text(hotline.name).font(.ds.headline)
                Text(hotline.phoneNumber).font(.ds.body).foregroundStyle(.secondary)
                if let description = hotline.description, !description.isEmpty {
                    Text(description).font(.ds.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            // Make the phone number tappable to initiate a call
            Image(systemName: "phone.arrow.up.right.fill")
                .foregroundStyle(.green)
        }
        .contentShape(Rectangle()) // Make entire row tappable
        .onTapGesture {
            call(phoneNumber: hotline.phoneNumber)
        }
    }
    
    // Helper to initiate phone call
    private func call(phoneNumber: String) {
        let telephone = "tel://"
        let formattedString = telephone + phoneNumber.filter { $0.isNumber } // Remove non-numeric chars
        guard let url = URL(string: formattedString) else { return }
        UIApplication.shared.open(url)
    }
}

// View for displaying a single resource link
struct ResourceRowView: View {
    let resource: SupportResource
    
    var body: some View {
        // Link automatically opens the URL in the browser
        Link(destination: resource.url) {
            HStack {
                Image(systemName: resource.iconName)
                    .foregroundStyle(Color.ds.accent)
                    .frame(width: 30) // Align icons
                
                VStack(alignment: .leading) {
                    Text(resource.title).font(.ds.headline)
                    Text(resource.description).font(.ds.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square") // Indicate external link
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary) // Ensure link text color matches app theme
    }
}

#Preview {
    SupportView(
        store: Store(initialState: SupportFeature.State()) {
            SupportFeature()
        }
    )
    // Add model container for previews even if not directly used by this feature yet
    .modelContainer(for: [ChatMessage.self, WellnessTask.self, CommunityPost.self], inMemory: true)
}
