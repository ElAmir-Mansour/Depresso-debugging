// In Features/Community/PostDetailView.swift
import SwiftUI
import SwiftData

struct PostDetailView: View {
    // Receives the post data, displays read-only like count
    let post: CommunityPost

    private var postImage: Image? {
         guard let data = post.imageData, let uiImage = UIImage(data: data) else { return nil }
         return Image(uiImage: uiImage)
     }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                // User Info Header
                 HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
                     Image(systemName: "person.circle.fill")
                         .resizable().scaledToFit().frame(width: 40, height: 40)
                         .foregroundStyle(.gray.opacity(0.5))
                     VStack(alignment: .leading) {
                         Text("Anonymous User").font(.ds.caption.weight(.semibold))
                         Text("Posted \(post.creationDate, style: .relative) ago").font(.ds.caption).foregroundStyle(.secondary)
                     }
                     Spacer()
                 }

                 // Title
                 if !post.title.isEmpty {
                     Text(post.title).font(.ds.title)
                 }

                 // Image
                 if let image = postImage {
                     image
                         .resizable().scaledToFit().frame(maxWidth: .infinity)
                         .cornerRadius(8)
                 }

                 // Full Content
                 Text(post.content).font(.ds.body)

                Divider()

                // ✅ Updated Action Buttons Row (Read-Only Like Count)
                HStack(spacing: DesignSystem.Spacing.medium) {
                    // Display Like Button State + Count
                    HStack(spacing: 4) {
                        Image(systemName: post.likeCount > 0 ? "heart.fill" : "heart")
                            .foregroundStyle(post.likeCount > 0 ? .red : .secondary)
                        if post.likeCount > 0 {
                            Text("\(post.likeCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Placeholder Reply/Share
                    Button {} label: { Image(systemName: "arrowshape.turn.up.forward") }
                        .buttonStyle(.plain)

                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.top, DesignSystem.Spacing.small)

            }
            .padding()
        }
        .navigationTitle(post.title.isEmpty ? "Story" : post.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Preview
#Preview {
     let container = try! ModelContainer(for: CommunityPost.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
     let context = container.mainContext
     let previewImageData = UIImage(systemName: "photo")?.jpegData(compressionQuality: 0.8)
     let samplePost = CommunityPost(title: "Detail View Title", content: "This is the full content of the post...", imageData: previewImageData, likeCount: 12)
     let _ = { context.insert(samplePost) }() // Correct preview data insertion

     return NavigationStack { // Wrap in NavStack for title
         PostDetailView(post: samplePost)
     }
     .modelContainer(container)
}
