//
// WisdomRow.swift
// TMTL 2
//☎️
// Created by Jaden Schwartz on 6/4/25.
//

import SwiftUI

// ── PopButtonStyle.swift (moved here for scope) ──
struct PopButtonStyle: ButtonStyle {
    var normalScale: CGFloat = 1
    var pressedScale: CGFloat = 1.3
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : normalScale)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0),
                value: configuration.isPressed
            )
    }
}

// ── WisdomRow.swift ──
struct WisdomRow: View {
    let entry: WisdomEntry
    let hasVoted: Bool
    let isMine: Bool
    let upAction: () -> Void
    let downAction: () -> Void
    let idleBolt: LinearGradient
    let activeBolt: LinearGradient
    let idleCloud: LinearGradient
    let activeCloud: LinearGradient
    let userReaction: ReactionType?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.text)
                .font(.custom("Palatino", size: 18))
                .foregroundColor(isMine ? .yellow.opacity(0.9) : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                Button(action: upAction) {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(userReaction == .up ? activeBolt : idleBolt)
                        .shadow(
                            color: userReaction == .up ? .white.opacity(0.8) : .clear,
                            radius: userReaction == .up ? 8 : 0
                        )
                }
                .buttonStyle(PopButtonStyle())
                .scaleEffect(userReaction == .up ? 1.2 : 1.0)
                .animation(.spring(), value: userReaction)
                
                Text("\(entry.score)")
                    .font(.custom("Palatino", size: 16))
                    .foregroundColor(.white)
                
                Button(action: downAction) {
                    Image(systemName: "arrow.down")
                        .font(.headline)
                        .foregroundStyle(userReaction == .down ? activeCloud : idleCloud)
                        .shadow(
                            color: userReaction == .down ? .blue.opacity(0.8) : .clear,
                            radius: userReaction == .down ? 8 : 0
                        )
                }
                .buttonStyle(PopButtonStyle())
                .scaleEffect(userReaction == .down ? 1.2 : 1.0)
                .animation(.spring(), value: userReaction)
            }
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WisdomRow_Previews: PreviewProvider {
    static var previews: some View {
        WisdomRow(
            entry: WisdomEntry(
                id: "1",
                text: "Preview wisdom text goes here.",
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(3600),
                upvotes: 5,
                downvotes: 1,
                commentCount: 2,
                authorId: "author123"
            ),
            hasVoted: false,
            isMine: false,
            upAction: {},
            downAction: {},
            idleBolt: LinearGradient(
                colors: [Color.yellow.opacity(0.6), Color.yellow.opacity(0.4)],
                startPoint: .top, endPoint: .bottom
            ),
            activeBolt: LinearGradient(
                colors: [Color.white, Color.yellow],
                startPoint: .top, endPoint: .bottom
            ),
            idleCloud: LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.3)],
                startPoint: .top, endPoint: .bottom
            ),
            activeCloud: LinearGradient(
                colors: [Color.blue, Color.blue],
                startPoint: .top, endPoint: .bottom
            ),
            userReaction: nil
        )
        .background(Color.black.ignoresSafeArea())
        .previewLayout(.sizeThatFits)
    }
}
