import SwiftUI
import UserNotifications

struct AddWisdomView: View {
    // Developer override for testing wipe-day
    @AppStorage("devWipeDayOverride") private var devWipeDayOverride = false
    // Persist when the user may next submit (seconds since 1970)
    @AppStorage("nextWisdomSubmission") private var nextSubmissionTimestamp: Double = 0
    // For immediate deep-link on save:
    @Environment(\.openURL) private var openURL
    
    // MARK: – State
    @State private var wisdomText: String = ""
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false
    @FocusState private var editorFocused: Bool
    
    // ← NEW: track whether a save request is in flight
    @State private var isSaving: Bool = false
    
    // Countdown & Logo
    @State private var glow: Bool = false
    @State private var timeRemaining: TimeInterval = 0
    @State private var logoOpacity: Double = 0
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let maxChars = 1000
    
    /// The “next allowed” date
    private var expiryDate: Date {
        Date(timeIntervalSince1970: nextSubmissionTimestamp)
    }
    /// Disable on the 1st of each month (MT)
    private var isWipeDay: Bool {
#if DEBUG
        if devWipeDayOverride { return true }
#endif
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        return cal.component(.day, from: Date()) == 1
    }
    /// Whether you can submit now
    private var canSubmit: Bool {
#if DEBUG
        true
#else
        Date() >= expiryDate
#endif
    }
    private var showThankYou: Bool {
        !canSubmit
    }
    
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
            
        } else if showThankYou {
            thankYouView
            
        } else {
            editorFormView
        }
    }
    
    private var thankYouView: some View {
        VStack(spacing: 16) {
            Text("Thank you for your wisdom!")
                .font(.custom("Palatino", size: 20))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 250)
                .opacity(logoOpacity)
                .shadow(color: .indigo.opacity(glow ? 10 : 0), radius: glow ? 30 : 0)
            
            Text("Next entry: \(timerString)")
                .font(.caption)
                .foregroundColor(.yellow)
            
#if DEBUG
            Button("Submit Another") {
                wisdomText = ""
                nextSubmissionTimestamp = 0
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white, lineWidth: 2)
            )
#endif
        }
        .onAppear {
            logoOpacity = 0; glow = false
            withAnimation(.easeIn(duration: 3.5)) { logoOpacity = 1 }
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .delay(1)
                    .repeatForever(autoreverses: true)
            ) { glow = true }
        }
        .onReceive(countdownTimer) { _ in
            let remaining = expiryDate.timeIntervalSinceNow
            timeRemaining = max(0, remaining)
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
            
            Text("You may only post once every 24 hours. Entries expire at the end of the month; choose wisely.")
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
                    // then show the thank-you UI and schedule next submit…
                    nextSubmissionTimestamp = Date().addingTimeInterval(24*3600).timeIntervalSince1970
                    wisdomText = ""
                    scheduleWisdomReadyNotification(at: Date().addingTimeInterval(24*3600))
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
    
    private var timerString: String {
        let t = max(0, Int(timeRemaining))
        return String(format: "%02d:%02d:%02d", t/3600, (t%3600)/60, t%60)
    }
    
    private func scheduleWisdomReadyNotification(at date: Date) {
        NotificationScheduler.scheduleWisdomReady(at: date)
    }

    
    
    struct AddWisdomView_Previews: PreviewProvider {
        static var previews: some View {
            AddWisdomView()
        }
    }
}
