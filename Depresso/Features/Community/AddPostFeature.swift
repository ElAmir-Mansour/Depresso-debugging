// In Features/Community/AddPostFeature.swift
import Foundation
import ComposableArchitecture
import SwiftData
import PhotosUI // ✅ Import PhotosUI
import SwiftUI // Import for Image

@Reducer
struct AddPostFeature {
    @ObservableState
    struct State: Equatable {
        var title: String = ""
        var content: String = ""
        var isSaving: Bool = false
        
        // ✅ ADDED: State for the PhotosPicker item and the loaded image data
        var selectedPhotoItem: PhotosPickerItem? = nil
        var selectedImageData: Data? = nil
        
        // Computed property to create an Image view from the data for preview
        var selectedImage: Image? {
            guard let data = selectedImageData else { return nil }
            guard let uiImage = UIImage(data: data) else { return nil }
            return Image(uiImage: uiImage)
        }

        var isValid: Bool {
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case cancelButtonTapped
        case saveButtonTapped
        case delegate(Delegate)
        
        // ✅ ADDED: Action to handle the result of loading image data
        case imageDataLoaded(Result<Data?, Error>)

        enum Delegate {
            case savePost(CommunityPost)
        }
    }

    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .cancelButtonTapped:
                return .run { _ in await self.dismiss() }

            case .saveButtonTapped:
                guard state.isValid else { return .none }
                state.isSaving = true

                // Include imageData when creating the post
                let newPost = CommunityPost(
                    title: state.title,
                    content: state.content,
                    imageData: state.selectedImageData // Pass the image data
                )
                return .run { send in
                    await send(.delegate(.savePost(newPost)))
                    await self.dismiss()
                }

            // ✅ ADDED: Handle changes to the selected photo item
            case .binding(\.selectedPhotoItem):
                // This runs when the user selects a photo in the picker
                guard let newItem = state.selectedPhotoItem else {
                    // User cleared selection or selection failed
                    state.selectedImageData = nil
                    return .none
                }
                // Return an effect to load the image data asynchronously
                return .run { send in
                    // Request the data (specify type, e.g., .jpeg)
                    let result = await Result { try await newItem.loadTransferable(type: Data.self) }
                    await send(.imageDataLoaded(result))
                }
                
            // ✅ ADDED: Handle the loaded image data
            case .imageDataLoaded(.success(let data)):
                state.selectedImageData = data
                return .none
                
            case .imageDataLoaded(.failure(let error)):
                print("❌ Failed to load image data: \(error)")
                // Optionally show an alert to the user
                state.selectedImageData = nil // Clear potentially stale data
                return .none

            case .binding:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
