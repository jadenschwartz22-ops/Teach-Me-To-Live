//☎️
import SwiftUI

struct WelcomeView: View {
    // Bind to the tab selection so we can switch tabs when “Go to The Repository” is tapped
    @Binding var selection: Int
    
    // MARK: – State for cycling messages, opacity, rain, etc.
    @State private var currentMessageIndex = 0
    @State private var textOpacity: Double = 1
    @State private var showRain = false
    @State private var slideOffset: CGFloat = 0
    @State private var blurRadius: CGFloat = 0
    @State private var cycleTask: Task<Void, Never>? = nil
    
    // MARK: – Messages and display durations
    private let messages = [
        "'The Unexamined Life Is Not Worth Living' – Socrates",
        "This place is a repository for wisdom. Take a piece of advice, and leave one if you'd like.",
        "And remember…",
        "All these moments will be lost in time…",
        "Go to The Repository"
    ]
    private let displayTimes: [Double] = [5, 5, 3, 10, 10]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // ── Push content down by 50% of screen height ──
                Spacer()
                    .frame(height: UIScreen.main.bounds.height * 0.4)
                
                // ── Messages area ──
                VStack(spacing: 30) {
                    if currentMessageIndex == messages.count - 1 {
                        Button(action: {
                            // Switch to the “Repository” tab (index 1)
                            selection = 1
                        }) {
                            Text(messages[currentMessageIndex])
                                .underline()
                                .foregroundColor(.white)
                                .font(.custom("Palatino", size: 24))
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                        .opacity(textOpacity)
                        .offset(y: slideOffset)
                        .blur(radius: blurRadius)
                    } else {
                        Text(messages[currentMessageIndex])
                            .foregroundColor(.white)
                            .font(.custom("Palatino", size: 24))
                            .multilineTextAlignment(.center)
                            .padding()
                            .opacity(textOpacity)
                            .offset(y: slideOffset)
                            .blur(radius: blurRadius)
                    }
                }
                
                // ── Fill remaining space below ──
                Spacer()
            }
            
            // ── Show rain emitter if triggered ──
            if showRain {
                RainEmitter(animate: true)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            cycleMessages()
        }
        .onDisappear {
            cycleTask?.cancel()
        }
    }
    
    /// Cycle through each message, fading in/out and optionally starting rain.
    private func cycleMessages() {
        cycleTask?.cancel()
        cycleTask = Task {
            for idx in 0..<messages.count {
                await MainActor.run {
                    currentMessageIndex = idx
                    textOpacity = 0
                    if idx == 2 {
                        showRain = true
                    }
                }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        textOpacity = 1
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(displayTimes[idx] * 1_000_000_000))
                if idx < messages.count - 1 {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            textOpacity = 0
                        }
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var selection = 0
        var body: some View {
            WelcomeView(selection: $selection)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
