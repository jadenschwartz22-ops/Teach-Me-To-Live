import AVFoundation
import Speech

/// Live speech-to-text into the composer. Tap once to start, again to stop.
final class Dictation: ObservableObject {
    @Published private(set) var isListening = false

    private let recognizer = SFSpeechRecognizer(locale: .current)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle(current: String, onText: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        if isListening { stop(); return }
        Task { @MainActor in
            guard await Self.authorized() else {
                onError("Dictation needs Microphone and Speech Recognition access. Turn them on for TMTL in iOS Settings.")
                return
            }
            do { try start(current: current, onText: onText) }
            catch { onError("Dictation isn't available right now.") }
        }
    }

    func stop() {
        guard isListening else { return }
        isListening = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func start(current: String, onText: @escaping (String) -> Void) throws {
        guard let recognizer, recognizer.isAvailable else { throw CocoaError(.featureUnsupported) }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()
        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                // The result after stop can be empty on-device; never let it erase what was dictated.
                if let said = result?.bestTranscription.formattedString, !said.isEmpty {
                    onText(current.isEmpty ? said : current + " " + said)
                }
                if error != nil || result?.isFinal == true {
                    self?.stop()
                    self?.task = nil
                }
            }
        }
    }

    private static func authorized() async -> Bool {
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        return speech ? await AVAudioApplication.requestRecordPermission() : false
    }
}
