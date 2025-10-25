// Depresso/Features/Community/CommunityView.swift

import SwiftUI
import ComposableArchitecture
import PhotosUI

struct CommunityView: View {
    let store: StoreOf<CommunityFeature>
    
    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if store.isLoading {
                        ProgressView("Loading posts...")
                    } else if store.posts.isEmpty {
                        EmptyPostsView(onAddPost: {
                            store.send(.addPostTapped)
                        })
                    } else {
                        ForEach(store.posts) { post in
                            PostCard(post: post)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Community")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.addPostTapped)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .onAppear {
                store.send(.viewAppeared)
            }
            .sheet(isPresented: $store.showAddPost.sending(\.dismissAddPost)) {
                AddPostSheet(store: store)
            }
        }
    }
}

struct PostCard: View {
    let post: CommunityFeature.PostValue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(post.author.prefix(1)))
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(post.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Content
            Text(post.content)
                .font(.body)
            
            // Image (if exists)
            if let thumbnailImage = post.thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 300)
                    .clipped()
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct AddPostSheet: View {
    let store: StoreOf<CommunityFeature>
    @Environment(\.dismiss) var dismiss
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                Form {
                    Section("Share Your Thoughts") {
                        TextField("What's on your mind?", text: $store.newPostContent.sending(\.postContentChanged), axis: .vertical)
                            .lineLimit(5...10)
                    }
                    
                    Section("Add Image (Optional)") {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("Select Photo", systemImage: "photo")
                        }
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    store.send(.imageSelected(data))
                                }
                            }
                        }
                        
                        if let imageData = store.selectedImage,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        }
                    }
                }
                .navigationTitle("New Post")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Post") {
                            store.send(.submitPost)
                        }
                        .disabled(store.newPostContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}

struct EmptyPostsView: View {
    let onAddPost: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No posts yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Be the first to share!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Create Post", action: onAddPost)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}
