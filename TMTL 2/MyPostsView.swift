import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MyPostsView: View {
    @Environment(\.openURL) private var systemOpenURL: OpenURLAction
    @StateObject private var viewModel = MyPostsViewModel()
    @State private var showSearch = false
    @State private var searchText = ""
    @FocusState private var searchFieldFocused: Bool

    @State private var oldPosts: [WisdomEntry] = []
    @State private var highlightedPostIDs: Set<String> = []

    @State private var lastMonthTop: [WisdomEntry] = []

    private var isWipeDay: Bool {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        return cal.component(.day, from: Date()) == 1
    }

    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private var myWinningEntries: [WisdomEntry] {
        lastMonthTop.filter { $0.authorId == currentUserId }
    }

    @ViewBuilder
    var body: some View {
        if isWipeDay {
            wipeDayMyPostsView
        } else {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    headerView
                    PostsListView(
                        posts: filteredPosts,
                        highlightedIDs: $highlightedPostIDs,
                        openURL: customOpenURL
                    )
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                if searchFieldFocused { searchFieldFocused = false }
            })
            .toolbar { keyboardToolbar }
            .onAppear {
                viewModel.startListening()
                oldPosts = viewModel.posts
            }
            .onDisappear {
                viewModel.stopListening()
            }
            .onReceive(viewModel.$posts) { newPosts in
                let oldByID = Dictionary(uniqueKeysWithValues: oldPosts.map { ($0.id, $0.commentCount) })
                for post in newPosts {
                    if let oldCount = oldByID[post.id],
                       post.commentCount > oldCount
                    {
                        let seen = UserDefaults.standard.integer(
                            forKey: "lastSeenComments_\(post.id)"
                        )
                        if post.commentCount > seen {
                            highlightedPostIDs.insert(post.id)
                        }
                    }
                }
                oldPosts = newPosts
            }
            .onReceive(NotificationCenter.default.publisher(for: .commentsViewed)) { notif in
                if let postId = notif.userInfo?["postId"] as? String {
                    markCommentsAsSeen(postId: postId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openComments)) { notif in
                guard let postId = notif.userInfo?["postId"] as? String else { return }
                highlightedPostIDs.insert(postId)
            }
        }
    }

    private var wipeDayMyPostsView: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("My Posts")
                    .foregroundColor(.white)
                    .font(.custom("Palatino", size: 28))
                    .padding(.top, 20)

                if myWinningEntries.isEmpty {
                    Text("Good luck this month")
                        .foregroundColor(.gray)
                        .font(.custom("Palatino", size: 16))
                        .padding(.top, 8)
                    Spacer()
                } else {
                    VStack(spacing: 14) {
                        ForEach(myWinningEntries) { entry in
                            Button {
                                if let url = URL(string: "tmtl2://comments?wisdomId=\(entry.id)") {
                                    systemOpenURL(url)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.text)
                                        .font(.custom("Palatino", size: 18))
                                        .foregroundColor(.yellow)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    HStack(spacing: 10) {
                                        Label("\(entry.score)", systemImage: "star.fill")
                                        Label("\(entry.commentCount)", systemImage: "bubble.left.fill")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.yellow.opacity(0.9))
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.yellow, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            FirestoreService.shared.fetchTopLastMonthEntries(limit: 3) { result in
                if case .success(let entries) = result { lastMonthTop = entries }
            }
        }
    }

    private var customOpenURL: OpenURLAction {
        OpenURLAction { url in
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let wisdomId = comps.queryItems?.first(where: { $0.name == "wisdomId" })?.value
            {
                markCommentsAsSeen(postId: wisdomId)
            }
            systemOpenURL(url)
            return .handled
        }
    }

    private func markCommentsAsSeen(postId: String) {
        let count = viewModel.posts.first(where: { $0.id == postId })?.commentCount ?? 0
        UserDefaults.standard.set(count, forKey: "lastSeenComments_\(postId)")
        highlightedPostIDs.remove(postId)
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            Text("My Posts")
                .foregroundColor(.white)
                .font(.custom("Palatino", size: 28))
                .padding(.top, 20)
                .padding(.bottom, 8)

            SearchBarView(
                showSearch: $showSearch,
                searchText: $searchText,
                searchFieldFocused: _searchFieldFocused
            )
            Spacer().frame(height: showSearch ? 8 : 0)
        }
    }

    private var filteredPosts: [WisdomEntry] {
        guard !searchText.isEmpty else { return viewModel.posts }
        return viewModel.posts.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { searchFieldFocused = false }
        }
    }

    private struct SearchBarView: View {
        @Binding var showSearch: Bool
        @Binding var searchText: String
        @FocusState var searchFieldFocused: Bool

        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        withAnimation { showSearch.toggle() }
                        if showSearch {
                            searchFieldFocused = true
                        } else {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 16)
                }
                if showSearch {
                    TextField("Search my posts…", text: $searchText)
                        .focused($searchFieldFocused)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    @MainActor
    class MyPostsViewModel: ObservableObject {
        @Published var posts: [WisdomEntry] = []
        @Published var isLoading = true

        private let db = Firestore.firestore()
        private let userId = Auth.auth().currentUser!.uid
        private var listener: ListenerRegistration?

        func startListening() {
            isLoading = true
            listener?.remove()

            let now = Timestamp(date: Date())
            let query = db.collection("wisdom")
                .whereField("authorId", isEqualTo: userId)
                .whereField("expiresAt", isGreaterThan: now)
                .order(by: "createdAt", descending: true)

            listener = query.addSnapshotListener { [weak self] snap, error in
                guard let self = self, let snap = snap else {
                    self?.isLoading = false
                    return
                }
                self.isLoading = false

                self.posts = snap.documents.compactMap { doc in
                    let d = doc.data()
                    guard
                        let text         = d["text"]          as? String,
                        let tsCreated    = d["createdAt"]     as? Timestamp,
                        let tsExpires    = d["expiresAt"]     as? Timestamp,
                        let up           = d["upvotes"]       as? Int,
                        let down         = d["downvotes"]     as? Int,
                        let commentCount = d["commentCount"]  as? Int,
                        let authorId     = d["authorId"]      as? String
                    else { return nil }

                    return WisdomEntry(
                        id:           doc.documentID,
                        text:         text,
                        createdAt:    tsCreated.dateValue(),
                        expiresAt:    tsExpires.dateValue(),
                        upvotes:      up,
                        downvotes:    down,
                        commentCount: commentCount,
                        authorId:     authorId
                    )
                }
            }
        }

        func stopListening() {
            listener?.remove()
            listener = nil
        }
    }

    struct MyPostsView_Previews: PreviewProvider {
        static var previews: some View {
            MyPostsView()
        }
    }
}
