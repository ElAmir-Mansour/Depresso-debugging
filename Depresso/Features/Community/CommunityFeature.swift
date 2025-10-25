// Depresso/Features/Community/CommunityFeature.swift

import ComposableArchitecture
import UIKit

@Reducer
struct CommunityFeature {
    
    @ObservableState
    struct State: Equatable {
        var posts: [PostValue] = []
        var isLoading: Bool = false
        var showAddPost: Bool = false
        var selectedImage: Data? = nil
        var newPostContent: String = ""
    }
    
    struct PostValue: Equatable, Identifiable {
        let id: UUID
        var content: String
        var imageData: Data?
        var timestamp: Date
        var author: String
        
        // Computed property for thumbnail
        var thumbnailImage: UIImage? {
            guard let data = imageData else { return nil }
            // Resize to thumbnail to save memory
            return UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 300, height: 300))
        }
    }
    
    enum Action {
        case viewAppeared
        case postsLoaded([PostValue])
        case addPostTapped
        case imageSelected(Data?)
        case postContentChanged(String)
        case submitPost
        case postSubmitted
        case dismissAddPost
    }
    
    @Dependency(\.swiftDataClient) var swiftDataClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                
            case .viewAppeared:
                state.isLoading = true
                
                return .run { send in
                    let posts = try await swiftDataClient.fetchPosts()
                    let postValues = posts.map { post in
                        PostValue(
                            id: post.id,
                            content: post.content,
                            imageData: post.imageData,
                            timestamp: post.timestamp,
                            author: "Anonymous" // Or fetch from user profile
                        )
                    }
                    await send(.postsLoaded(postValues))
                }
                
            case let .postsLoaded(posts):
                state.posts = posts
                state.isLoading = false
                return .none
                
            case .addPostTapped:
                state.showAddPost = true
                state.newPostContent = ""
                state.selectedImage = nil
                return .none
                
            case let .imageSelected(data):
                // Compress image before storing
                if let data = data, let image = UIImage(data: data) {
                    state.selectedImage = image.jpegData(compressionQuality: 0.7)
                } else {
                    state.selectedImage = nil
                }
                return .none
                
            case let .postContentChanged(content):
                state.newPostContent = content
                return .none
                
            case .submitPost:
                guard !state.newPostContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return .none
                }
                
                let content = state.newPostContent
                let imageData = state.selectedImage
                
                let newPost = PostValue(
                    id: UUID(),
                    content: content,
                    imageData: imageData,
                    timestamp: .now,
                    author: "You"
                )
                
                state.posts.insert(newPost, at: 0)
                state.showAddPost = false
                
                return .run { send in
                    try await swiftDataClient.savePost(content, imageData)
                    await send(.postSubmitted)
                }
                
            case .postSubmitted:
                return .none
                
            case .dismissAddPost:
                state.showAddPost = false
                state.newPostContent = ""
                state.selectedImage = nil
                return .none
            }
        }
    }
}
