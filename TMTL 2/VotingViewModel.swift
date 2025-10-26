import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class VotingViewModel: ObservableObject {
    @Published var wisdomList: [WisdomEntry] = []
    @Published var lastMonthTop: [WisdomEntry] = []
    @Published var votesToday: Int = 0
    @Published var userReactions: [String: ReactionType] = [:]
    @Published var isLoading: Bool = false

    private let service = FirestoreService.shared
    private let voteKey = "voteTimestamps"

    /// Live listener for commentCount updates (normal days)
    private var countListener: ListenerRegistration?

    /// Live listener for wipe-day "Top of last month" entries
    private var wipeDayListener: ListenerRegistration?

    // Coalesce reaction updates (kept for future use)
    private var reactionsBuffer: [String: ReactionType] = [:]
    private var reactionsFlushWorkItem: DispatchWorkItem?

    var userId: String { Auth.auth().currentUser!.uid }

    private var enforceLimit: Bool {
    #if DEBUG
        return false
    #else
        return true
    #endif
    }

    let maxVotes = 5
    var canVote: Bool { !enforceLimit || votesToday < maxVotes }

    func load() async {
        isLoading = true
        do {
            let entries = try await fetchWisdomAsync()
            let blocked = UserDefaults.standard.stringArray(forKey: "blockedUsers") ?? []
            let filtered = entries.filter { !blocked.contains($0.authorId) }
            self.wisdomList = filtered
            self.fetchUserReactions()
            self.isLoading = false
            self.subscribeToCommentCountUpdates()   // keeps repo live on normal days
        } catch {
            self.isLoading = false
        }
        updateVotesToday()
        if Calendar.current.component(.day, from: Date()) == 1 {
            loadLastMonthTop() // wipe day
        }
    }

    private func subscribeToCommentCountUpdates() {
        // tear down any existing listener
        countListener?.remove()

        // only watch non‐expired posts
        let now = Timestamp(date: Date())
        countListener = Firestore.firestore()
            .collection("wisdom")
            .whereField("expiresAt", isGreaterThan: now)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let docs = snap?.documents else { return }
                // Build a single patched array first (one publish)
                var list = self.wisdomList
                var changed = false
                for doc in docs {
                    let id = doc.documentID
                    let newCount = doc.data()["commentCount"] as? Int ?? 0
                    if let idx = list.firstIndex(where: { $0.id == id }) {
                        let old = list[idx]
                        if old.commentCount != newCount {
                            list[idx] = WisdomEntry(
                                id:           old.id,
                                text:         old.text,
                                createdAt:    old.createdAt,
                                expiresAt:    old.expiresAt,
                                upvotes:      old.upvotes,
                                downvotes:    old.downvotes,
                                commentCount: newCount,
                                authorId:     old.authorId
                            )
                            changed = true
                        }
                    }
                }
                if changed {
                    self.wisdomList = list
                }
            }
    }

    /// Stop all listeners
    func stopListening() {
        countListener?.remove()
        countListener = nil
        wipeDayListener?.remove()
        wipeDayListener = nil
    }

    private func fetchWisdomAsync() async throws -> [WisdomEntry] {
        try await withCheckedThrowingContinuation { continuation in
            service.fetchWisdom { result in
                switch result {
                case .success(let entries): continuation.resume(returning: entries)
                case .failure(let error):   continuation.resume(throwing: error)
                }
            }
        }
    }

    private func updateVotesToday() {
        let now = Date().timeIntervalSince1970
        let stored = UserDefaults.standard.array(forKey: voteKey) as? [TimeInterval] ?? []
        votesToday = stored.filter { now - $0 < 24*3600 }.count
    }

    // MARK: Reaction fetching (single publish)
    private func bufferReaction(_ rt: ReactionType, for id: String) {
        reactionsBuffer[id] = rt
        reactionsFlushWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let batch = self.reactionsBuffer
            self.reactionsBuffer.removeAll(keepingCapacity: true)
            // Single merge → single @Published fire
            self.userReactions.merge(batch) { _, new in new }
        }
        reactionsFlushWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func fetchUserReactions() {
        let uid = userId
        let db = Firestore.firestore()

        // One query across all /reactions subcollections
        db.collectionGroup("reactions")
            .whereField("authorId", isEqualTo: uid)
            .getDocuments { [weak self] snap, _ in
                guard let self = self else { return }
                var dict: [String: ReactionType] = [:]
                for doc in snap?.documents ?? [] {
                    guard
                        let typeString = doc.data()["type"] as? String,
                        let rt = ReactionType(rawValue: typeString)
                    else { continue }
                    // parent of "reactions" is the wisdom doc
                    if let wisdomId = doc.reference.parent.parent?.documentID {
                        dict[wisdomId] = rt
                    }
                }
                // 🔧 Fix: hop to the main actor before mutating published state
                Task { @MainActor in
                    self.userReactions = dict
                }
            }
    }

    /// Optimistic voting update with existing patch & sort logic
    func vote(_ entry: WisdomEntry, type: ReactionType) {
        let current = userReactions[entry.id]

        // If tapping same reaction, remove it
        if current == type {
            // 1) immediate local undo
            userReactions[entry.id] = nil
            decrementLocalVoteCount()

            if let idx = wisdomList.firstIndex(where: { $0.id == entry.id }) {
                let old = wisdomList[idx]
                let newUp   = (current == .up)   ? old.upvotes   - 1 : old.upvotes
                let newDown = (current == .down) ? old.downvotes - 1 : old.downvotes
                let patched = WisdomEntry(
                    id: old.id,
                    text: old.text,
                    createdAt: old.createdAt,
                    expiresAt: old.expiresAt,
                    upvotes: newUp,
                    downvotes: newDown,
                    commentCount: old.commentCount,
                    authorId: old.authorId
                )
                var list = wisdomList
                list.remove(at: idx)
                let insertIndex = list.firstIndex {
                    patched.upvotes - patched.downvotes > $0.upvotes - $0.downvotes ||
                    (patched.upvotes - patched.downvotes == $0.upvotes - $0.downvotes &&
                     patched.createdAt > $0.createdAt)
                } ?? list.count
                list.insert(patched, at: insertIndex)
                withAnimation(.easeOut(duration: 0.18)) {
                    wisdomList = list
                }
            }

            // 2) backend call
            service.removeVote(wisdomId: entry.id) { error in
                if let err = error { print("❌ removeVote failed:", err) }
            }
            return
        }

        // Otherwise, cast a new vote
        guard canVote else { return }

        // 1) immediate local apply
        userReactions[entry.id] = type
        incrementLocalVoteCount()

        if let idx = wisdomList.firstIndex(where: { $0.id == entry.id }) {
            let old = wisdomList[idx]
            let upMinus   = (current == .up)   ? 1 : 0
            let downMinus = (current == .down) ? 1 : 0
            var newUp   = old.upvotes   - upMinus
            var newDown = old.downvotes - downMinus
            if type == .up   { newUp += 1 }
            if type == .down { newDown += 1 }
            let patched = WisdomEntry(
                id: old.id,
                text: old.text,
                createdAt: old.createdAt,
                expiresAt: old.expiresAt,
                upvotes: newUp,
                downvotes: newDown,
                commentCount: old.commentCount,
                authorId: old.authorId
            )
            var list = wisdomList
            list.remove(at: idx)
            let insertIndex = list.firstIndex {
                patched.upvotes - patched.downvotes > $0.upvotes - $0.downvotes ||
                (patched.upvotes - patched.downvotes == $0.upvotes - $0.downvotes &&
                 patched.createdAt > $0.createdAt)
            } ?? list.count
            list.insert(patched, at: insertIndex)
            withAnimation(.easeOut(duration: 0.18)) {
                wisdomList = list
            }
        }

        // 2) backend call
        service.vote(wisdomId: entry.id, type: type) { error in
            if let err = error { print("❌ vote failed:", err) }
        }
    }

    func loadLastMonthTop() {
        service.fetchTopLastMonthEntries(limit: 3) { result in
            switch result {
            case .success(let entries):
                self.lastMonthTop = entries
                // Start live updates for those specific posts
                self.subscribeToWipeDayCommentCounts(for: entries.map { $0.id })
            case .failure(let error):
                print("Failed to fetch last-month top entries: \(error)")
            }
        }
    }

    // Live listener for wipe-day "top of last month" entries
    private func subscribeToWipeDayCommentCounts(for ids: [String]) {
        // Tear down any existing wipe-day listener
        wipeDayListener?.remove()
        wipeDayListener = nil
        guard !ids.isEmpty else { return }

        // IDs count is small (limit=3), safe for 'in' query
        wipeDayListener = Firestore.firestore()
            .collection("wisdom")
            .whereField(FieldPath.documentID(), in: ids)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let docs = snap?.documents else { return }
                var updated = self.lastMonthTop
                var changed = false
                for doc in docs {
                    let id = doc.documentID
                    let newCount = doc.data()["commentCount"] as? Int ?? 0
                    if let idx = updated.firstIndex(where: { $0.id == id }) {
                        let old = updated[idx]
                        if old.commentCount != newCount {
                            updated[idx] = WisdomEntry(
                                id: old.id,
                                text: old.text,
                                createdAt: old.createdAt,
                                expiresAt: old.expiresAt,
                                upvotes: old.upvotes,
                                downvotes: old.downvotes,
                                commentCount: newCount,   // live patch
                                authorId: old.authorId
                            )
                            changed = true
                        }
                    }
                }
                if changed {
                    self.lastMonthTop = updated
                }
            }
    }

    private func incrementLocalVoteCount() {
        let now = Date().timeIntervalSince1970
        var votes = UserDefaults.standard.array(forKey: voteKey) as? [TimeInterval] ?? []
        votes = votes.filter { now - $0 < 24*3600 }
        votes.append(now)
        UserDefaults.standard.set(votes, forKey: voteKey)
        votesToday = votes.count
    }

    private func decrementLocalVoteCount() {
        let now = Date().timeIntervalSince1970
        var votes = UserDefaults.standard.array(forKey: voteKey) as? [TimeInterval] ?? []
        if !votes.isEmpty { votes.removeLast() }
        votes = votes.filter { now - $0 < 24*3600 }
        UserDefaults.standard.set(votes, forKey: voteKey)
        votesToday = votes.count
    }
}
