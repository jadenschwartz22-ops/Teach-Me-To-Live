import SwiftUI

struct PostsListView: View {
    // Flag to suppress scroll when coming back from the Repository deep-link
    static var didNavigateToRepo = false

    let posts: [WisdomEntry]
    @Binding var highlightedIDs: Set<String>
    let openURL: OpenURLAction

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear.frame(height: 0).id("top")
                VStack(spacing: 20) {
                    ForEach(posts) { entry in
                        // Entire row: text + icons
                        VStack(alignment: .leading, spacing: 8) {
                            // Post text
                            Text(entry.text)
                                .font(.custom("Palatino", size: 18))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(3)
                                .truncationMode(.tail)
                                .padding(.horizontal)

                            // Icons row, left-aligned
                            HStack(spacing: 16) {
                                Label("\(entry.upvotes)", systemImage: "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Label("\(entry.downvotes)", systemImage: "arrow.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                let isNew = highlightedIDs.contains(entry.id)
                                Button {
                                    markSeenAndDeepLink(entryId: entry.id)
                                } label: {
                                    Label(
                                        "\(entry.commentCount)",
                                        systemImage: isNew ? "bubble.left.fill" : "bubble.left"
                                    )
                                    .font(.caption)
                                }
                                .foregroundColor(isNew ? .blue : .gray)
                                .buttonStyle(PlainButtonStyle())

                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    highlightedIDs.contains(entry.id) ? Color.blue : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            navigateToPost(entry.id)
                        }
                        .id(entry.id)
                    }
                }
                .padding(.bottom, 150)
            }
            // Guarded scroll-to-top on manual My Posts tap
            .onReceive(NotificationCenter.default.publisher(for: .didTapMyPostsTabManual)) { _ in
                // defer so CommentsView can set its flag first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    if CommentsView.didHandleMyPostsTap {
                        // Popping out of CommentsView → clear flag, skip scroll
                        CommentsView.didHandleMyPostsTap = false
                    } else if PostsListView.didNavigateToRepo {
                        // Coming back from a Repository deep-link → clear flag, skip scroll
                        PostsListView.didNavigateToRepo = false
                    } else {
                        // Genuine double-tap on My Posts → scroll to top
                        withAnimation { proxy.scrollTo("top", anchor: .top) }
                    }
                }
            }
            // Deep-link into a specific post
            .onReceive(NotificationCenter.default.publisher(for: .didSelectMyPost)) { notif in
                guard let postId = notif.userInfo?["postId"] as? String else { return }
                withAnimation { proxy.scrollTo(postId, anchor: .center) }
                clearHighlight(postId: postId)
            }
            // Deep-link into comments (generic)
            .onReceive(NotificationCenter.default.publisher(for: .openComments)) { notif in
                guard let postId = notif.userInfo?["postId"] as? String else { return }
                withAnimation { proxy.scrollTo(postId, anchor: .center) }
                clearHighlight(postId: postId)
            }
        }
    }

    /// Marks all comments seen, clears the blue border, then opens Comments at bottom.
    private func markSeenAndDeepLink(entryId: String) {
        let count = posts.first(where: { $0.id == entryId })?.commentCount ?? 0
        UserDefaults.standard.set(count, forKey: "lastSeenComments_\(entryId)")
        highlightedIDs.remove(entryId)
        if let url = URL(string: "tmtl2://repoComments?wisdomId=\(entryId)&commentId=bottom") {
            openURL(url)
        }
    }

    /// Opens the repository view centered on this post
    private func navigateToPost(_ entryId: String) {
        // Set flag so returning from repo won’t scroll
        PostsListView.didNavigateToRepo = true
        if let url = URL(string: "tmtl2://repository/\(entryId)") {
            openURL(url)
        }
    }

    /// Clears the blue border (no navigation)
    private func clearHighlight(postId: String) {
        let count = posts.first(where: { $0.id == postId })?.commentCount ?? 0
        UserDefaults.standard.set(count, forKey: "lastSeenComments_\(postId)")
        highlightedIDs.remove(postId)
    }
}
