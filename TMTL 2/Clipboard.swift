import SwiftUI

extension Notification.Name {
    static let didCopyText = Notification.Name("didCopyText")
}

enum Clipboard {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        NotificationCenter.default.post(name: .didCopyText, object: nil)
    }
}

private struct CopyToast: ViewModifier {
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if visible {
                    Text("Copied")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 110)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didCopyText)) { _ in
                withAnimation { visible = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { visible = false }
                }
            }
    }
}

extension View {
    func copyToast() -> some View { modifier(CopyToast()) }
}
