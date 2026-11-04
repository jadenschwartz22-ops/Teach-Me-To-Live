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

/// A TextEditor that tidies whitespace on every change (debounced), with a placeholder, a clear button
/// (undoable for a few seconds) and a keyboard bar: Paste, Copy, Clear, Done.
struct FilteredTextEditor: View {
  @Binding var text: String
  var placeholder = "Share a quote or a lesson…"
  @FocusState private var isFocused: Bool
  @State private var cleared: String?

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
      .padding(.trailing, text.isEmpty ? 0 : 28)
      .background(Color.gray.opacity(0.4))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.white.opacity(0.6), lineWidth: 1)
      )
      .overlay(alignment: .topLeading) {
        if text.isEmpty {
          Text(placeholder)
            .foregroundColor(.white.opacity(0.4))
            .padding(.horizontal, 6).padding(.vertical, 8)
            .allowsHitTesting(false)
        }
      }
      .overlay(alignment: .topTrailing) {
        if !text.isEmpty {
          Button(action: clear) {
            Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(.white.opacity(0.7))
          }
          .padding(6)
          .accessibilityLabel("Clear text")
        } else if cleared != nil {
          Button("Undo") { restore() }
            .font(.callout.bold()).foregroundColor(.yellow)
            .padding(8)
        }
      }

      // ✅ Always attach the keyboard toolbar on the editor (safe host).
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          if isFocused {
            PasteButton(payloadType: String.self) { strings in
              guard let s = strings.first else { return }
              Task { @MainActor in text = text.isEmpty ? s : text + (text.hasSuffix(" ") || text.hasSuffix("\n") ? "" : " ") + s }
            }
            .labelStyle(.titleOnly)
            .buttonBorderShape(.capsule)
            Button("Copy") { Clipboard.copy(text) }.disabled(text.isEmpty)
            Button("Clear", action: clear).disabled(text.isEmpty)
            Spacer()
            Button("Done") { isFocused = false }.bold()
          }
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
        if !text.isEmpty { cleared = nil }
        guard !text.isEmpty else { return }
        debouncer.send(text)
      }
  }

  private func clear() {
    cleared = text
    text = ""
    Task { try? await Task.sleep(for: .seconds(5)); cleared = nil }
  }

  private func restore() {
    if let cleared { text = cleared }
    cleared = nil
  }
}
