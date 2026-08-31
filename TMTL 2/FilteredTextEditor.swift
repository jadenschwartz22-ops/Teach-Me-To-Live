//☎️
import SwiftUI
import Combine

extension Character {
    var isEmojiCustom: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation }
    }
}

extension String {
    var removingEmojis: String {
        filter { !$0.isEmojiCustom }
    }
}

/// A TextEditor that tidies whitespace on every change (debounced) and shows a
/// stable Done toolbar.
struct FilteredTextEditor: View {
  @Binding var text: String
  @FocusState private var isFocused: Bool

  // Debounce to avoid doing regex work on every keystroke
  @State private var debouncer = PassthroughSubject<String, Never>()
  @State private var cancellable: AnyCancellable?

  var body: some View {
    TextEditor(text: $text)
      .frame(maxWidth: .infinity)
      .frame(minHeight: 44)                 // keep host non-zero so toolbar can layout
      .focused($isFocused)
      .scrollContentBackground(.hidden)
      .foregroundColor(.white)
      .background(Color.gray.opacity(0.4))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.white.opacity(0.6), lineWidth: 1)
      )

      // ✅ Always attach the keyboard toolbar on the editor (safe host).
      .toolbar {
        ToolbarItem(placement: .keyboard) {
          Button("Done") { isFocused = false }
        }
      }

      // Debounced formatting pipeline
      .onAppear {
        cancellable = debouncer
          .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
          .sink { newValue in
            let filtered = newValue
              .removingEmojis
              .replacingOccurrences(of: #"\n{4,}"#,
                                    with: "\n\n\n",
                                    options: .regularExpression)
              .replacingOccurrences(of: #" {31,}"#,
                                    with: String(repeating: " ", count: 30),
                                    options: .regularExpression)
              .replacingOccurrences(of: #"(?m)^[ \t]+$"#,
                                    with: "",
                                    options: .regularExpression)
            if filtered != text { text = filtered }
          }
      }
      .onDisappear {
        cancellable?.cancel()
        cancellable = nil
      }
      .onChange(of: text) {
        guard !text.isEmpty else { return }
        debouncer.send(text)
      }

  }
}
