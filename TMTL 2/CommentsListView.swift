// CommentsListView.swift

import SwiftUI

struct CommentsListView: View {
let comments: [Comment]
@Binding var highlightedIDs: Set<String>
@Binding var scrollProxy: ScrollViewProxy?
@ObservedObject var viewModel: CommentsViewModel
let onBlock: (Comment) -> Void
let onReport: (Comment, String) -> Void

var body: some View {
List {
ForEach(comments) { comment in
BlockquoteComment(text: comment.text)
.id(comment.id)
.listRowBackground(Color.black)
.listRowSeparator(.hidden)
.highlightable(
isOn:
highlightedIDs.contains(comment.id)
|| !viewModel.isSeen(commentId: comment.id)
|| Date().timeIntervalSince(comment.timestamp) < 30,
cornerRadius: 4
)
.contextMenu {
// Report in red
Button(role: .destructive) {
onReport(comment, "Inappropriate content")
} label: {
Label("Report", systemImage: "flag.fill")
}
// Block user (default color)
Button {
onBlock(comment)
} label: {
Label("Block User", systemImage: "hand.raised.fill")
}
}
.onAppear {
if !viewModel.isSeen(commentId: comment.id) {
viewModel.markSeen(commentId: comment.id)
}
if highlightedIDs.contains(comment.id) {
DispatchQueue.main.async {
highlightedIDs.remove(comment.id)
}
}
}
}

// “Bottom” sentinel for scroll-to-bottom notifications
Color.black
.frame(height: 0.1)
.listRowBackground(Color.black)
.listRowSeparator(.hidden)
.id("bottom")
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
}
}
