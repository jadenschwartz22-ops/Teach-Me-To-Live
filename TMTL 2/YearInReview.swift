import SwiftUI
import FirebaseFirestore

/// Dec 29 - Jan 2: a card on the feed opening the year's top posts from `yearInReview/{year}`.
@MainActor
final class YearInReview: ObservableObject {
    static let shared = YearInReview()

    struct Item: Identifiable {
        let id = UUID()
        let text: String
        let score: Int
        let createdAt: Date?
    }

    @Published private(set) var items: [Item]?   // nil until the doc loads; stays nil if missing
    @Published var isPresented = false

    private var cal: Calendar { .current }

    /// The year being reviewed: Dec 29-31 -> this year, Jan 1-2 (and any later push tap) -> last year.
    var year: Int {
        let c = cal.dateComponents([.year, .month], from: Date())
        return c.month == 1 ? c.year! - 1 : c.year!
    }

    var inWindow: Bool {
        let c = cal.dateComponents([.month, .day], from: Date())
        return (c.month == 12 && c.day! >= 29) || (c.month == 1 && c.day! <= 2)
    }

    var showCard: Bool { inWindow && items != nil }

    func load() async {
        guard let data = try? await Firestore.firestore().collection("yearInReview").document("\(year)").getDocument().data(),
              let posts = data["posts"] as? [[String: Any]] else { items = nil; return }
        items = posts.compactMap { p in
            guard let text = p["text"] as? String else { return nil }
            return Item(text: text, score: p["score"] as? Int ?? 0, createdAt: (p["createdAt"] as? Timestamp)?.dateValue())
        }
    }

    func open() {
        NotificationCenter.default.post(name: .switchToRepositoryTab, object: nil)
        isPresented = true
        Task { await load() }
    }
}

struct YearInReviewCard: View {
    @ObservedObject var review: YearInReview

    var body: some View {
        if review.showCard {
            Button { review.isPresented = true } label: {
                HStack {
                    Image(systemName: "sparkles").foregroundColor(.yellow)
                    Text("Top posts of \(String(review.year))")
                        .font(.custom("Palatino", size: 18))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.gray)
                }
                .neumorphic()
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .buttonStyle(.plain)
        }
    }
}

struct YearInReviewList: View {
    @ObservedObject var review: YearInReview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let items = review.items {
                    List(Array(items.prefix(10).enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("#\(index + 1)").font(.headline).foregroundColor(.yellow)
                                Spacer()
                                if let date = item.createdAt {
                                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(.caption).foregroundColor(.gray)
                                }
                                Text("\(item.score) ⚡").font(.caption.weight(.semibold)).foregroundColor(.yellow)
                            }
                            Text(item.text)
                                .font(.custom("Palatino", size: 18)).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .neumorphic()
                        .listRowBackground(Color.black)
                        .listRowSeparator(.hidden)
                        .contextMenu { Button { Clipboard.copy(item.text) } label: { Label("Copy", systemImage: "doc.on.doc") } }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                } else {
                    Text("Nothing here yet.").foregroundColor(.gray)
                }
            }
            .navigationTitle("Top posts of \(String(review.year))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .copyToast()
        .preferredColorScheme(.dark)
    }
}
