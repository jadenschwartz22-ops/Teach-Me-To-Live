import SwiftUI
import UserNotifications

struct AddWisdomView: View {
    // Developer override for testing wipe-day
    @AppStorage("devWipeDayOverride") private var devWipeDayOverride = false
    // For immediate deep-link on save:
    @Environment(\.openURL) private var openURL
    
    // MARK: – State
    @State private var wisdomText: String = ""
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false
    @FocusState private var editorFocused: Bool
    
    // ← NEW: track whether a save request is in flight
    @State private var isSaving: Bool = false
    
    private let maxChars = 1000
    
    /// Disable on the 1st of each month (MT)
    private var isWipeDay: Bool {
#if DEBUG
        if devWipeDayOverride { return true }
#endif
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        return cal.component(.day, from: Date()) == 1
    }
    /// Posting is unlimited; the composer is always available.
    private var canSubmit: Bool { true }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
#if DEBUG
                Button {
                    devWipeDayOverride.toggle()
                } label: {
                    Text(devWipeDayOverride ? "🚨 WIPE-DAY ON" : "wipe-day off")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
#endif
                modeBadge
                contentArea
            }
            .padding()
        }
        .onTapGesture { editorFocused = false }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var modeBadge: some View {
#if DEBUG
        Text("🛠️ DEBUG MODE")
            .font(.caption)
            .foregroundColor(.yellow)
#else
        EmptyView()
#endif
    }
    
    @ViewBuilder
    private var contentArea: some View {
        if isWipeDay {
            Text("Submissions are closed—check back tomorrow.\n\nToday is for remembering")
                .font(.custom("Palatino", size: 20))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
        } else {
            editorFormView
        }
    }
    
    
    private var editorFormView: some View {
        VStack(spacing: 16) {
            FilteredTextEditor(text: $wisdomText)
                .focused($editorFocused)
                .frame(height: 200)
                .padding(.horizontal)
            
            Text("\(wisdomText.count)/\(maxChars)")
                .foregroundColor(wisdomText.count > maxChars ? .red : .gray)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal)
            
            Button {
                attemptSaveWisdom()
            } label: {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 24, height: 24)
                } else {
                    Text("Save Wisdom")
                }
            }
            .disabled(
                !canSubmit
                || isWipeDay
                || wisdomText.isEmpty
                || wisdomText.count > maxChars
                || isSaving    // ← Prevent taps while already saving
            )
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white, lineWidth: 2)
            )
            
            Text("Entries expire at the end of the month; choose wisely.")
                .font(.custom("Palatino", size: 14))
                .foregroundColor(.yellow)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private func attemptSaveWisdom() {
        // ← Prevent double-fire
        guard !isSaving else { return }
        isSaving = true
        
        let dbExpiry = firstOfNextMonth()
        FirestoreService.shared.addWisdom(wisdomText, expiresAt: dbExpiry) { docID, error in
            DispatchQueue.main.async {
                // ← Clear saving flag immediately upon callback
                isSaving = false
                
                if let err = error {
                    errorMessage = "Failed to save wisdom: \(err.localizedDescription)"
                    showErrorAlert = true
                } else if let id = docID {
                    // ① tell the app we just posted new wisdom
                    NotificationCenter.default.post(
                        name: .didPostWisdom,
                        object: nil,
                        userInfo: ["postId": id]
                    )
                    // ② now deep-link into Repo as before
                    if let url = URL(string: "tmtl2://repository/\(id)") {
                        openURL(url)
                    }
                    wisdomText = ""
                }
                
                
            }
            
        }
    }
    
    private func firstOfNextMonth() -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        var comps = cal.dateComponents([.year, .month], from: Date())
        if comps.month == 12 { comps.year! += 1; comps.month = 1 }
        else { comps.month! += 1 }
        comps.day = 1; comps.hour = 0; comps.minute = 0; comps.second = 0
        return cal.date(from: comps)!
    }
    
    
    
    
    struct AddWisdomView_Previews: PreviewProvider {
        static var previews: some View {
            AddWisdomView()
        }
    }
}
