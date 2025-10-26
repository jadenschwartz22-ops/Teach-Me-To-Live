//☎️
import SwiftUI

struct TermsView: View {
  let onAccept: () -> Void
  let onDecline: () -> Void

  // Load your Markdown or static text however you like
  private var termsText: String {
    guard
      let url = Bundle.main.url(forResource: "TermsOfUse", withExtension: "md"),
      let contents = try? String(contentsOf: url, encoding: .utf8)
    else {
      return "Unable to load Terms of Use."
    }
    return contents
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        Text(termsText)
          .padding()
      }
      .navigationTitle("Terms of Use")
      .toolbar {
        // Left‐side “Decline” button
        ToolbarItem(placement: .cancellationAction) {
          Button("Decline", role: .cancel) {
            onDecline()
          }
        }
        // Right‐side “Accept” button
        ToolbarItem(placement: .confirmationAction) {
          Button("Accept") {
            onAccept()
          }
        }
      }
    }
  }
}

struct TermsView_Previews: PreviewProvider {
  static var previews: some View {
    TermsView(onAccept: {}, onDecline: {})
  }
}
