// In Features/Community/AddPostView.swift
import SwiftUI
import ComposableArchitecture
import PhotosUI // ✅ Import PhotosUI

struct AddPostView: View {
    @Bindable var store: StoreOf<AddPostFeature>

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $store.title)
                
                Section("Your Story") {
                    TextEditor(text: $store.content)
                        .frame(minHeight: 200, alignment: .top)
                        .multilineTextAlignment(.leading)
                }
                
                // ✅ ADDED: Section for Image Picker and Preview
                Section("Add Image (Optional)") {
                    // The PhotosPicker bound to the state's selectedPhotoItem
                    PhotosPicker(selection: $store.selectedPhotoItem, matching: .images) {
                        Label("Select Photo", systemImage: "photo")
                    }
                    
                    // Show preview if an image is selected
                    if let image = store.selectedImage {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200) // Limit preview size
                            .cornerRadius(8)
                            .padding(.vertical) // Add some padding around the preview
                    }
                    
                    // Button to clear selection
                    if store.selectedImageData != nil {
                        Button("Remove Image", role: .destructive) {
                            store.selectedPhotoItem = nil // Triggers the binding action
                        }
                    }
                }
            }
            .navigationTitle("New Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        store.send(.cancelButtonTapped)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        store.send(.saveButtonTapped)
                    }
                    .disabled(!store.isValid)
                }
            }
            .overlay {
                if store.isSaving {
                    ProgressView()
                        .padding()
                        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

#Preview {
    AddPostView(
        store: Store(initialState: AddPostFeature.State()) {
            AddPostFeature()
        }
    )
    .modelContainer(for: CommunityPost.self, inMemory: true)
}
