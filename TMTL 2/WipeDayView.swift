//☎️
//  WipeDayView.swift
//  TMTL 2
//
//  Created by Jaden Schwartz on 6/4/25.
//

// WipeDayView.swift
import SwiftUI

struct WipeDayView: View {
    let lastMonthTop: [WisdomEntry]
    let loadLastMonthTop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Top entries of last month:")
                .font(.custom("Palatino", size: 20))
                .foregroundColor(.yellow)
                .padding(.horizontal)

            if lastMonthTop.isEmpty {
                Text("Loading entries")
                    .font(.custom("Palatino", size: 16))
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ForEach(lastMonthTop) { entry in
                    NavigationLink(destination: CommentsView(wisdom: entry)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.text)
                                .font(.custom("Palatino", size: 18))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up")
                                Text("\(entry.score)")
                                Image(systemName: "arrow.down")
                                Text("\(entry.downvotes)")
                                Image(systemName: "bubble.left.fill")
                                Text("\(entry.commentCount)")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct WipeDayView_Previews: PreviewProvider {
    static var previews: some View {
        WipeDayView(
            lastMonthTop: [
                // example data here
                WisdomEntry(
                    id: "1",
                    text: "Example wisdom",
                    createdAt: Date(),
                    expiresAt: Date().addingTimeInterval(3600),
                    upvotes: 10,
                    downvotes: 2,
                    commentCount: 3,
                    authorId: "user123"
                )
            ],
            loadLastMonthTop: {}
        )
    }
}
