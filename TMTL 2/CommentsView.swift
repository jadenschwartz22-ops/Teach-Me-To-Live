import SwiftUI
import Combine
import FirebaseAuth

// MARK: – Block-Quote Style Comment
struct BlockquoteComment: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.custom("Palatino", size: 16))
            .foregroundColor(.white.opacity(0.9))
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.05))
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2),
                alignment: .leading
            )
            .cornerRadius(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
    }
}

struct CommentsView: View {
    static var didHandleRepoTap  = false
    static var didHandleMyPostsTap = false
    
    let wisdom: WisdomEntry
    @StateObject private var vm: CommentsViewModel
    @State private var highlightedCommentIDs: Set<String> = []
    @State private var newComment = ""
    @FocusState private var commentFieldFocused: Bool
    @Environment(\.presentationMode) private var presentationMode
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isPostExpanded = false
    
    // Alerts for block & report
    @State private var showBlockAlert  = false
    @State private var blockAlertMessage = ""
    @State private var showReportAlert = false
    @State private var reportAlertMessage = ""
    
    init(wisdom: WisdomEntry) {
        self.wisdom = wisdom
        _vm = StateObject(wrappedValue: CommentsViewModel(wisdomId: wisdom.id))
    }
    
    /// Filter out empty text and blocked authors
    private var visibleComments: [Comment] {
        let blocked = UserDefaults.standard.stringArray(forKey: "blockedUsers") ?? []
        return vm.comments
            .filter {
                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !blocked.contains($0.authorId)
            }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            fullPostList
            
            // ── Input Bar ──
            HStack(spacing: 12) {
                FilteredTextEditor(text: $newComment, placeholder: "Add a comment…")
                    .frame(height: 40)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .focused($commentFieldFocused)
                
                Button("Send") {
                    vm.post(text: newComment)
                    let key = "lastSeenComments_\(wisdom.id)"
                    let seen = UserDefaults.standard.integer(forKey: key)
                    UserDefaults.standard.set(seen + 1, forKey: key)
                    newComment = ""
                    commentFieldFocused = false
                }
                .disabled(newComment.isEmpty)
                .foregroundColor(newComment.isEmpty ? .gray : .white)
            }
            .padding()
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea(edges: .bottom))
        .onTapGesture { commentFieldFocused = false }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        
        // ── Lifecycle & deep-link handlers ──
        .onAppear {
            vm.startListening()
            UserDefaults.standard.set(vm.comments.count,
                                      forKey: "lastSeenComments_\(wisdom.id)")
            NotificationCenter.default.post(
                name: .commentsViewed,
                object: nil,
                userInfo: ["postId": wisdom.id]
            )
        }
        .onDisappear { vm.stopListening() }
        .onReceive(NotificationCenter.default.publisher(for: .openComments)) { notif in
            guard let postId = notif.userInfo?["postId"] as? String,
                  postId == wisdom.id else { return }
            UserDefaults.standard.set(vm.comments.count,
                                      forKey: "lastSeenComments_\(wisdom.id)")
            if let cid = notif.userInfo?["commentId"] as? String,
               cid != "bottom"
            {
                highlightedCommentIDs.insert(cid)
                withAnimation { scrollProxy?.scrollTo(cid, anchor: .center) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToCommentBottom)) { notif in
            guard let postId = notif.userInfo?["postId"] as? String,
                  postId == wisdom.id else { return }
            withAnimation { scrollProxy?.scrollTo("bottom", anchor: .bottom) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didTapRepositoryTab)) { _ in
            CommentsView.didHandleRepoTap = true
            presentationMode.wrappedValue.dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeComments)) { _ in
            presentationMode.wrappedValue.dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didTapMyPostsTabManual)) { _ in
            CommentsView.didHandleMyPostsTap = true
            presentationMode.wrappedValue.dismiss()
        }
        
        .copyToast()
        // ── Block & Report Alerts ──
        .alert(reportAlertMessage, isPresented: $showReportAlert) {
            Button("OK", role: .cancel) {}
        }
        .alert(blockAlertMessage, isPresented: $showBlockAlert) {
            Button("OK", role: .cancel) {}
        }
    }
    
    private var fullPostList: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // ── Post Header ──
                VStack(alignment: .leading, spacing: 4) {
                    Text(wisdom.text)
                        .font(.custom("Palatino", size: 18))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(isPostExpanded ? nil : 3)
                    
                    if wisdom.text.count > 200 {
                        Button {
                            withAnimation { isPostExpanded.toggle() }
                        } label: {
                            Text(isPostExpanded ? "Show less" : "Show more")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal)
                .layoutPriority(1)
                
                Divider()
                    .background(Color.white)
                    .padding(.horizontal)
                
                // ── Extracted Comments List ──
                CommentsListView(
                    comments: visibleComments,
                    highlightedIDs: $highlightedCommentIDs,
                    scrollProxy: $scrollProxy,
                    viewModel: vm,
                    onBlock: { comment in
                        vm.blockComment(comment)
                        if comment.authorId == Auth.auth().currentUser?.uid {
                            blockAlertMessage = "You can’t block yourself."
                        } else {
                            blockAlertMessage = "User blocked until next wipe-day."
                        }
                        showBlockAlert = true
                    },
                    onReport: { comment, _ in
                        vm.reportComment(comment, reason: "Inappropriate content") { _ in }
                        reportAlertMessage = "Thanks—comment reported."
                        showReportAlert = true
                    }
                )
            }
            .onAppear { scrollProxy = proxy }
        }
    }
}
