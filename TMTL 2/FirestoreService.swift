import Foundation
import FirebaseFirestore
import FirebaseAuth

enum ReactionType: String {
case up, down
}

/// A single wisdom entry with creation and expiration dates
struct WisdomEntry: Identifiable {
let id: String
let text: String
let createdAt: Date
let expiresAt: Date
let upvotes: Int
let downvotes: Int
let commentCount: Int
let authorId: String
var score: Int { upvotes - downvotes }
}

/// A single comment on a wisdom entry
struct Comment: Identifiable {
let id: String
let text: String
let timestamp: Date
let authorId: String
}

class FirestoreService {
static let shared = FirestoreService()
let db = Firestore.firestore()

// MARK: – Fetch Wisdom Entries
func fetchWisdom(
completion: @escaping (Result<[WisdomEntry], Error>) -> Void
) {
let nowTs = Timestamp(date: Date())
db.collection("wisdom")
.whereField("expiresAt", isGreaterThan: nowTs)
.order(by: "score", descending: true)
.order(by: "createdAt", descending: true)
.getDocuments { snapshot, error in
if let error = error {
completion(.failure(error)); return
}
let entries = snapshot?.documents.compactMap { doc -> WisdomEntry? in
let data = doc.data()
guard
let text = data["text"] as? String,
let tsCreated = data["createdAt"] as? Timestamp,
let tsExpires = data["expiresAt"] as? Timestamp,
let up = data["upvotes"] as? Int,
let down = data["downvotes"] as? Int
else { return nil }
let author = data["authorId"] as? String ?? ""
let commentCount = data["commentCount"] as? Int ?? 0
return WisdomEntry(
id: doc.documentID,
text: text,
createdAt: tsCreated.dateValue(),
expiresAt: tsExpires.dateValue(),
upvotes: up,
downvotes: down,
commentCount: commentCount,
authorId: author
)
} ?? []
completion(.success(entries))
}
}

// MARK: – Fetch Top Entries From Last Month
func fetchTopLastMonthEntries(
limit: Int = 3,
completion: @escaping (Result<[WisdomEntry], Error>) -> Void
) {
var cal = Calendar.current
cal.timeZone = TimeZone(identifier: "America/Denver")!
var comps = cal.dateComponents([.year, .month], from: Date())
comps.day = 1; comps.hour = 0; comps.minute = 0; comps.second = 0
let startOfThisMonth = cal.date(from: comps)!
let startOfLastMonth = cal.date(byAdding: .month, value: -1, to: startOfThisMonth)!
let startTS = Timestamp(date: startOfLastMonth)
let endTS  = Timestamp(date: startOfThisMonth)

db.collection("wisdom")
.whereField("createdAt", isGreaterThanOrEqualTo: startTS)
.whereField("createdAt", isLessThan: endTS)
.order(by: "score", descending: true)
.order(by: "createdAt", descending: true)
.limit(to: limit)
.getDocuments { snapshot, error in
if let error = error {
completion(.failure(error)); return
}
let entries = snapshot?.documents.compactMap { doc -> WisdomEntry? in
let d = doc.data()
guard
let text = d["text"] as? String,
let tsCreated = d["createdAt"] as? Timestamp,
let tsExpires = d["expiresAt"] as? Timestamp,
let up = d["upvotes"] as? Int,
let down = d["downvotes"] as? Int
else { return nil }
let author = d["authorId"] as? String ?? ""
let commentCount = d["commentCount"] as? Int ?? 0
return WisdomEntry(
id: doc.documentID,
text: text,
createdAt: tsCreated.dateValue(),
expiresAt: tsExpires.dateValue(),
upvotes: up,
downvotes: down,
commentCount: commentCount,
authorId: author
)
} ?? []
completion(.success(entries))
}
}

// MARK: – Add Wisdom Entry
func addWisdom(
_ text: String,
expiresAt: Date,
completion: @escaping (_ docID: String?, _ error: Error?) -> Void
) {
// 24 hr TTL on deleteAt
let ttlExpiry = expiresAt.addingTimeInterval(24 * 3600)
let data: [String: Any] = [
"text": text,
"authorId": Auth.auth().currentUser!.uid,
"createdAt":  FieldValue.serverTimestamp(),
"expiresAt":  Timestamp(date: expiresAt),
"deleteAt": Timestamp(date: ttlExpiry),
"upvotes":  0,
"downvotes":  0,
"score":  0,
"commentCount":0
]

// ① grab a new DocumentReference with an auto-ID
let docRef = db.collection("wisdom").document()

// ② then write into it, passing its documentID back in the callback
docRef.setData(data) { error in
completion(docRef.documentID, error)
}
}
// MARK: – Voting
func vote(
wisdomId: String,
type: ReactionType,
completion: @escaping (Error?) -> Void
) {
let uid = Auth.auth().currentUser!.uid
let wRef = db.collection("wisdom").document(wisdomId)
let rRef = wRef.collection("reactions").document(uid)

db.runTransaction({ transaction, errorPointer -> Any? in
do {
let wDoc = try transaction.getDocument(wRef)
var up  = wDoc.data()?["upvotes"]  as? Int ?? 0
var down = wDoc.data()?["downvotes"] as? Int ?? 0

if let old = try? transaction.getDocument(rRef),
let t  = old.data()?["type"] as? String,
let oldType = ReactionType(rawValue: t) {
switch oldType {
case .up:  up  -= 1
case .down: down -= 1
}
}

switch type {
case .up:  up  += 1
case .down: down += 1
}

let newScore = up - down
transaction.setData([
"type": type.rawValue,
"timestamp": Timestamp(date: Date()),
"authorId": uid
], forDocument: rRef)
transaction.updateData([
"upvotes": up,
"downvotes": down,
"score": newScore
], forDocument: wRef)

} catch let err as NSError {
errorPointer?.pointee = err
}
return nil
}, completion: { _, error in
completion(error)
})
}

func removeVote(
wisdomId: String,
completion: @escaping (Error?) -> Void
) {
let uid = Auth.auth().currentUser!.uid
let wRef = db.collection("wisdom").document(wisdomId)
let rRef = wRef.collection("reactions").document(uid)

db.runTransaction({ transaction, errorPointer -> Any? in
do {
let wDoc = try transaction.getDocument(wRef)
var up  = wDoc.data()?["upvotes"]  as? Int ?? 0
var down = wDoc.data()?["downvotes"] as? Int ?? 0

if let old = try? transaction.getDocument(rRef),
let t  = old.data()?["type"] as? String,
let oldType = ReactionType(rawValue: t) {
switch oldType {
case .up:  up  -= 1
case .down: down -= 1
}
}

let newScore = up - down
transaction.deleteDocument(rRef)
transaction.updateData([
"upvotes":  up,
"downvotes": down,
"score":  newScore
], forDocument: wRef)

} catch let err as NSError {
errorPointer?.pointee = err
}
return nil
}, completion: { _, error in
completion(error)
})
}

// MARK: – Comments
func fetchComments(
for wisdomId: String,
completion: @escaping (Result<[Comment], Error>) -> Void
) {
db.collection("wisdom")
.document(wisdomId)
.collection("comments")
.order(by: "timestamp", descending: false)
.getDocuments { snapshot, error in
if let error = error {
completion(.failure(error)); return
}
let comments = snapshot?.documents.compactMap { doc -> Comment? in
let data = doc.data()
guard
let text  = data["text"] as? String,
let ts  = data["timestamp"] as? Timestamp,
let authorId = data["authorId"] as? String  // ← pull authorId too
else { return nil }
return Comment(
id: doc.documentID,
text: text,
timestamp: ts.dateValue(),
authorId: authorId
)  } ?? []
completion(.success(comments))
}
}

/// Fetch the latest comment ID for a given post, to support deep-linking
func fetchLatestCommentId(
for wisdomId: String,
completion: @escaping (String?) -> Void
) {
db.collection("wisdom")
.document(wisdomId)
.collection("comments")
.order(by: "timestamp", descending: true)
.limit(to: 1)
.getDocuments { snapshot, error in
guard error == nil,
let doc = snapshot?.documents.first
else {
completion(nil)
return
}
completion(doc.documentID)
}
}

// MARK: – Add Comment
func addComment(
to wisdomId: String,
text: String,
completion: @escaping (Error?) -> Void
) {
let wRef = db.collection("wisdom").document(wisdomId)
let cRef = wRef.collection("comments").document()
let data: [String:Any] = [
"text": text,
"authorId": Auth.auth().currentUser!.uid,
"timestamp": Timestamp(date: Date())
]
cRef.setData(data) { error in
if let error = error {
completion(error); return
}
wRef.updateData([
"commentCount": FieldValue.increment(Int64(1))
]) { err in completion(err) }
}
}

// MARK: – Reporting & Auto-Deletion
/// Record a user report of objectionable content.
/// If a post receives 20 or more reports, delete it automatically.
func addReport(
wisdomId: String,
reporterId: String,
reason: String,
completion: @escaping (Error?) -> Void
) {
let reportsRef = db.collection("reports")
let data: [String:Any] = [
"wisdomId":  wisdomId,
"reporterId": reporterId,
"reason":  reason,
"timestamp": FieldValue.serverTimestamp()
]
reportsRef.addDocument(data: data) { error in
completion(error)
guard error == nil else { return }
reportsRef.whereField("wisdomId", isEqualTo: wisdomId)
.getDocuments { snapshot, err in
if let err = err {
print("❌ Error checking report count:", err)
return
}
let count = snapshot?.documents.count ?? 0
if count >= 20 {
self.db.collection("wisdom")
.document(wisdomId)
.delete { delErr in
if let delErr = delErr {
print("❌ Failed to delete post:", delErr)
}
}
}
}
}
}

/// Record a report against a comment.
/// If a comment receives 20 or more reports, delete it automatically.
func addCommentReport(
wisdomId: String,
commentId: String,
reporterId: String,
reason: String,
completion: @escaping (Error?) -> Void
) {
let reportsRef = db.collection("reports")
let data: [String:Any] = [
"wisdomId":  wisdomId,
"commentId": commentId,
"reporterId": reporterId,
"reason":  reason,
"timestamp": FieldValue.serverTimestamp()
]
reportsRef.addDocument(data: data) { error in
completion(error)
guard error == nil else { return }
reportsRef.whereField("commentId", isEqualTo: commentId)
.getDocuments { snapshot, err in
if let err = err {
print("❌ Error checking comment report count:", err)
return
}
let count = snapshot?.documents.count ?? 0
if count >= 20 {
self.db.collection("wisdom")
.document(wisdomId)
.collection("comments")
.document(commentId)
.delete { delErr in
if let delErr = delErr {
print("❌ Failed to delete comment:", delErr)
}
}
}
}
}
}
}
