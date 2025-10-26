// ReportedContentView.swift

import SwiftUI
import FirebaseFirestore

@MainActor
class ReportsViewModel: ObservableObject {
    struct WisdomReport: Identifiable {
        let id: String
        let text: String
        let count: Int
    }
    struct CommentReport: Identifiable {
        let id = UUID()
        let wisdomId: String
        let commentId: String
        let postText: String
        let commentSnippet: String
        let count: Int
    }

    @Published var wisdomReports: [WisdomReport] = []
    @Published var commentReports: [CommentReport] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {
        startListening()
    }
    deinit {
        listener?.remove()
    }

    private func startListening() {
        listener?.remove()
        listener = db.collection("reports")
            .addSnapshotListener { [weak self] snap, error in
                guard let self = self, let docs = snap?.documents else { return }

                // — Wisdom reports (unchanged) —
                let byWisdom = Dictionary(grouping: docs, by: { $0.data()["wisdomId"] as? String ?? "" })
                let wisdomIds = byWisdom.keys.filter { !$0.isEmpty }
                if wisdomIds.isEmpty {
                    self.wisdomReports = []
                } else {
                    let batchSize = 10
                    let batches = stride(from: 0, to: wisdomIds.count, by: batchSize)
                        .map { Array(wisdomIds[$0..<min($0+batchSize, wisdomIds.count)]) }
                    var fetchedPosts: [WisdomReport] = []
                    let group = DispatchGroup()
                    for batch in batches {
                        group.enter()
                        self.db.collection("wisdom")
                            .whereField(FieldPath.documentID(), in: batch)
                            .getDocuments { snap2, _ in
                                let partial = (snap2?.documents ?? []).compactMap { d -> WisdomReport? in
                                    let text = d.data()["text"] as? String ?? ""
                                    let count = byWisdom[d.documentID]?.count ?? 0
                                    return WisdomReport(id: d.documentID, text: text, count: count)
                                }
                                fetchedPosts.append(contentsOf: partial)
                                group.leave()
                            }
                    }
                    group.notify(queue: .main) {
                        self.wisdomReports = fetchedPosts
                    }
                }

                // — Comment reports, batched into one update —
                let byComment = Dictionary(grouping: docs, by: { $0.data()["commentId"] as? String ?? "" })
                let entries = byComment.filter { !$0.key.isEmpty }

                if entries.isEmpty {
                    self.commentReports = []
                } else {
                    var fetchedComments: [CommentReport] = []
                    let group = DispatchGroup()
                    for (commentId, grpDocs) in entries {
                        guard let wisdomId = grpDocs.first?.data()["wisdomId"] as? String else { continue }
                        let count = grpDocs.count
                        group.enter()

                        let postRef    = self.db.collection("wisdom").document(wisdomId)
                        let commentRef = postRef.collection("comments").document(commentId)

                        postRef.getDocument { postSnap, _ in
                            let postText = postSnap?.data()?["text"] as? String ?? ""
                            commentRef.getDocument { commentSnap, _ in
                                let snippet = commentSnap?.data()?["text"] as? String ?? ""
                                // only append if snippet non-empty
                                if !snippet.isEmpty {
                                    fetchedComments.append(
                                        CommentReport(
                                            wisdomId:       wisdomId,
                                            commentId:      commentId,
                                            postText:       postText,
                                            commentSnippet: snippet,
                                            count:          count
                                        )
                                    )
                                }
                                group.leave()
                            }
                        }
                    }
                    group.notify(queue: .main) {
                        self.commentReports = fetchedComments
                    }
                }
            }
    }

    func deleteWisdom(_ id: String) {
        db.collection("wisdom").document(id).delete()
    }
    func deleteComment(_ commentId: String, wisdomId: String) {
        db.collection("wisdom")
            .document(wisdomId)
            .collection("comments")
            .document(commentId)
            .delete()
    }
}

struct ReportedContentView: View {
    @StateObject private var vm = ReportsViewModel()

    var body: some View {
        NavigationView {
            List {
                // Reported posts section
                if !vm.wisdomReports.isEmpty {
                    Section("🚩 Reported Posts") {
                        ForEach(vm.wisdomReports) { r in
                            NavigationLink {
                                CommentsView(
                                    wisdom: WisdomEntry(
                                        id: r.id,
                                        text: r.text,
                                        createdAt: Date(),
                                        expiresAt: Date().addingTimeInterval(3600),
                                        upvotes: 0,
                                        downvotes: 0,
                                        commentCount: 0,
                                        authorId: ""
                                    )
                                )
                            } label: {
                                HStack {
                                    Text(r.text).lineLimit(2)
                                    Spacer()
                                    Text("\(r.count)")
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    vm.deleteWisdom(r.id)
                                    if let idx = vm.wisdomReports.firstIndex(where: { $0.id == r.id }) {
                                        vm.wisdomReports.remove(at: idx)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Reported comments section (filtered to non-blank)
                if !vm.commentReports.isEmpty {
                    Section("🚩 Reported Comments") {
                        ForEach(vm.commentReports) { r in
                            NavigationLink {
                                CommentsView(
                                    wisdom: WisdomEntry(
                                        id: r.wisdomId,
                                        text: r.postText,
                                        createdAt: Date(),
                                        expiresAt: Date().addingTimeInterval(3600),
                                        upvotes: 0,
                                        downvotes: 0,
                                        commentCount: 0,
                                        authorId: ""
                                    )
                                )
                            } label: {
                                HStack {
                                    Text(r.commentSnippet).lineLimit(2)
                                    Spacer()
                                    Text("\(r.count)")
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    vm.deleteComment(r.commentId, wisdomId: r.wisdomId)
                                    if let idx = vm.commentReports.firstIndex(where: { $0.id == r.id }) {
                                        vm.commentReports.remove(at: idx)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Fallback when nothing to show
                if vm.wisdomReports.isEmpty && vm.commentReports.isEmpty {
                    Text("No reported content")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Reports")
            .listStyle(.insetGrouped)
        }
    }
}
