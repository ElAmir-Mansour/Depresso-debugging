// In Features/Community/CommunityView.swift
import SwiftUI
import ComposableArchitecture
import SwiftData

struct CommunityView: View {
    @Bindable var store: StoreOf<CommunityFeature>

    var body: some View {
        NavigationStack {
            ZStack {
                if store.isLoading {
                    ProgressView("Loading Stories...")
                } else if let errorMessage = store.errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if store.posts.isEmpty {
                    ContentUnavailableView("No Stories Yet", systemImage: "text.bubble", description: Text("Be the first to share your journey."))
                } else {
                    List {
                        ForEach(store.posts) { post in
                            NavigationLink {
                                // Pass the store to the detail view if it needs actions
                                // For now, just pass the post data
                                PostDetailView(post: post)
                            } label: {
                                // Pass the store down to the row for actions
                                PostRowView(store: store, post: post)
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .id("communityList")
                }
            }
            .navigationTitle("Community Stories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.send(.addPostButtonTapped)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .task {
                await store.send(.task).finish()
            }
            .sheet(item: $store.scope(state: \.destination?.addPost, action: \.destination.addPost)) { addPostStore in
                AddPostView(store: addPostStore)
            }
        }
    }
}

// --- Updated PostRowView ---
struct PostRowView: View {
    // ✅ Receive the store to send actions
    // Use an unowned let because the store's lifetime is managed by the parent view
    @State var store: StoreOf<CommunityFeature>
    let post: CommunityPost

    private var postImage: Image? {
        guard let data = post.imageData, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "person.circle.fill")
                .resizable().scaledToFit().frame(width: 40, height: 40)
                .foregroundStyle(.gray.opacity(0.5))
                .padding(.leading, DesignSystem.Spacing.medium)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                // User Info, Title, Content, Image remain the same
                HStack {
                    Text("Anonymous User").font(.ds.caption.weight(.semibold))
                    Text("· \(post.creationDate, style: .relative)").font(.ds.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                if !post.title.isEmpty {
                    Text(post.title).font(.ds.headline).padding(.bottom, 2)
                }
                Text(post.content).font(.ds.body).lineLimit(3).foregroundStyle(.secondary)
                if let image = postImage {
                    image
                        .resizable().scaledToFill().frame(height: 50)
                        .clipped().cornerRadius(4)
                        .padding(.top, DesignSystem.Spacing.extraSmall)
                }

                // ✅ Updated Action Buttons Row
                HStack(spacing: DesignSystem.Spacing.medium) { // Reduced spacing slightly
                    // Like Button
                    Button {
                        // Send the like action with the post's ID
                        store.send(.likeButtonTapped(id: post.id))
                    } label: {
                        HStack(spacing: 4) {
                            // Use filled heart if liked > 0
                            Image(systemName: post.likeCount > 0 ? "heart.fill" : "heart")
                                .foregroundStyle(post.likeCount > 0 ? .red : .secondary)
                            // Display the like count if > 0
                            if post.likeCount > 0 {
                                Text("\(post.likeCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain) // Use plain style

                    // Reply/Share Button (Placeholder)
                    Button {} label: {
                        Image(systemName: "arrowshape.turn.up.forward")
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.top, DesignSystem.Spacing.small)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
    }
}

// --- Preview Needs Update ---
#Preview {
    let container = try! ModelContainer(for: CommunityPost.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let previewImageData = UIImage(systemName: "photo")?.jpegData(compressionQuality: 0.8)

    let samplePosts = [
        CommunityPost(title: "Liked Post", content: "This one has some likes.", imageData: previewImageData, likeCount: 5), // Liked post
        CommunityPost(title: "New Post", content: "This one has no likes yet.") // Unliked post
    ]
    // Use let _ = ... to execute setup code correctly in preview builder
    let _ = { samplePosts.forEach { context.insert($0) } }()

    let store = Store(initialState: CommunityFeature.State(posts: samplePosts, isLoading: false)) { // Pass posts to initial state
        CommunityFeature()
            .dependency(\.modelContext, try! ModelContextBox(context))
    }

    // Wrap in NavigationStack for previewing NavigationLink behavior
    return NavigationStack {
        CommunityView(store: store)
            .modelContainer(container)
    }
}
