import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class CommentsViewModel: ObservableObject {
    /// The live list of comments
    @Published var comments: [Comment] = []
    /// Firestore listener handle
    private var listener: ListenerRegistration?
    /// The ID of the wisdom post whose comments we’re showing
    private let wisdomId: String

    init(wisdomId: String) {
        self.wisdomId = wisdomId
    }

    /// Starts a real-time listener on the comments subcollection
    func startListening() {
        stopListening() // just in case
        let db = Firestore.firestore()
        listener = db
            .collection("wisdom")
            .document(wisdomId)
            .collection("comments")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let docs = snapshot?.documents else { return }
                self.comments = docs.compactMap { doc in
                    let data = doc.data()
                    guard
                        let text     = data["text"]      as? String,
                        let ts       = data["timestamp"] as? Timestamp,
                        let authorId = data["authorId"]  as? String
                    else { return nil }
                    return Comment(
                        id: doc.documentID,
                        text: text,
                        timestamp: ts.dateValue(),
                        authorId: authorId
                    )
                }
            }
    }

    /// Stops the Firestore listener
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    /// Posts a new comment and increments the parent’s commentCount in one atomic batch.
    func post(text: String, completion: ((Bool) -> Void)? = nil) {
        let db = Firestore.firestore()
        let batch = db.batch()

        // 1) Create the new comment document
        let commentRef = db
            .collection("wisdom")
            .document(wisdomId)
            .collection("comments")
            .document()
        let now = Timestamp(date: Date())
        let uid = Auth.auth().currentUser?.uid ?? ""
        let commentData: [String: Any] = [
            "text":      text,
            "timestamp": now,
            "authorId":  uid
        ]
        batch.setData(commentData, forDocument: commentRef)

        // 2) Increment the parent document’s commentCount
        let wisdomRef = db.collection("wisdom").document(wisdomId)
        batch.updateData(
            ["commentCount": FieldValue.increment(Int64(1))],
            forDocument: wisdomRef
        )

        // 3) Optimistic UI update
        let temp = Comment(
            id: UUID().uuidString,
            text: text,
            timestamp: now.dateValue(),
            authorId: uid
        )
        comments.append(temp)

        // 4) Commit the batch
        batch.commit { error in
            if let err = error {
                print("❌ Batch write failed:", err)
                completion?(false)
            } else {
                completion?(true)
            }
        }
    }

    // MARK: – Seen-state tracking

    /// Returns true if the comment has already been seen by this user
    func isSeen(commentId: String) -> Bool {
        let key = "seenComment_\(wisdomId)_\(commentId)"
        return UserDefaults.standard.object(forKey: key) != nil
    }

    /// Marks the comment as seen, persisting the timestamp
    func markSeen(commentId: String) {
        let key = "seenComment_\(wisdomId)_\(commentId)"
        UserDefaults.standard.set(Date(), forKey: key)
    }

    // MARK: – Block & Report

    /// Block all future comments from this comment’s author until next wipe-day
    func blockComment(_ comment: Comment) {
        let me = Auth.auth().currentUser?.uid
        guard comment.authorId != me else {
            print("❌ blockComment: attempted to block yourself (userId=\(me ?? "unknown")). Operation cancelled.")
            return
        }
        var blocked = UserDefaults.standard.stringArray(forKey: "blockedUsers") ?? []
        guard !blocked.contains(comment.authorId) else {
            print("⚠️ blockComment: user \(comment.authorId) is already blocked.")
            return
        }
        blocked.append(comment.authorId)
        UserDefaults.standard.set(blocked, forKey: "blockedUsers")
        print("✅ blockComment: user \(comment.authorId) blocked until next wipe-day.")
    }

    /// Report the given comment for the specified reason
    func reportComment(
        _ comment: Comment,
        reason: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let reporter = Auth.auth().currentUser?.uid ?? ""
        print("🔔 reportComment: reporting comment \(comment.id) by user \(comment.authorId) for “\(reason)”")
        FirestoreService.shared.addCommentReport(
            wisdomId: wisdomId,
            commentId: comment.id,
            reporterId: reporter,
            reason: reason
        ) { error in
            if let err = error {
                print("❌ reportComment: failed to report comment \(comment.id): \(err.localizedDescription)")
            } else {
                print("✅ reportComment: successfully reported comment \(comment.id).")
            }
            completion?(error)
        }
    }
}
