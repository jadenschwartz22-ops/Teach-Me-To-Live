//  NeumorphicStyle.swift
//  TMTL 2
//☎️
//  Created by Jaden Schwartz on 4/28/25.
//
import SwiftUI
struct Neumorphic: ViewModifier {
    var cornerRadius: CGFloat = 10
    var baseColor: Color = Color(red:0.12, green:0.12, blue:0.13)
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(baseColor)
                    .shadow(color: Color.white.opacity(0.08), radius: 4, x: -4, y: -4)
                    .shadow(color: Color.black.opacity(0.7),  radius: 4, x:  4, y:  4)
            )
    }
}
extension View {
    func neumorphic(cornerRadius: CGFloat = 10,
                    baseColor: Color = Color(red:0.12, green:0.12, blue:0.13)) -> some View {
        modifier(Neumorphic(cornerRadius: cornerRadius, baseColor: baseColor))
    }
}


// ── HighlightableBorder.swift ──
struct HighlightableBorder: ViewModifier {
    /// When `isOn` is true, draws a blue border that fades out over 30s
    let isOn: Bool
    var cornerRadius: CGFloat = 8

    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.blue.opacity(isOn ? opacity : 0), lineWidth: isOn ? 2 : 0)
            )
            .onAppear {
                guard isOn else { return }
                withAnimation(.linear(duration: 30)) {
                    opacity = 0
                }
            }
    }
}

extension View {
    /// Applies a blue fade-out border when `isOn` is true.
    func highlightable(isOn: Bool, cornerRadius: CGFloat = 8) -> some View {
        modifier(HighlightableBorder(isOn: isOn, cornerRadius: cornerRadius))
    }
}

