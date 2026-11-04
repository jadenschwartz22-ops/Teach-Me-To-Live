import SwiftUI
import PhotosUI
import VisionKit

/// Camera or library photo -> Live Text -> drag-select a quote -> insert into the composer.
struct QuoteScanButton: View {
    let onText: (String) -> Void

    @State private var showCamera = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var scan: ScanImage?

    private struct ScanImage: Identifiable { let id = UUID(); let image: UIImage }

    var body: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showCamera = true } label: { Label("Take Photo", systemImage: "camera") }
            }
            Button { showLibrary = true } label: { Label("Choose Photo", systemImage: "photo") }
        } label: {
            Image(systemName: "camera.viewfinder").font(.title3).foregroundColor(.white)
        }
        .accessibilityLabel("Capture a quote from a photo")
        .photosPicker(isPresented: $showLibrary, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    scan = ScanImage(image: img)
                }
                pickedItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { scan = ScanImage(image: $0) }.ignoresSafeArea()
        }
        .sheet(item: $scan) { item in
            QuoteScanSheet(image: item.image) { onText($0) }
        }
    }
}

@MainActor
private final class LiveTextModel: ObservableObject {
    enum State { case working, ready, empty, unsupported }
    let interaction = ImageAnalysisInteraction()
    @Published var state = State.working
    private var transcript = ""

    func analyze(_ image: UIImage) async {
        guard ImageAnalyzer.isSupported else { state = .unsupported; return }
        do {
            let analysis = try await ImageAnalyzer().analyze(image, configuration: .init(.text))
            transcript = analysis.transcript
            interaction.analysis = analysis
            interaction.preferredInteractionTypes = .textSelection
            state = transcript.isEmpty ? .empty : .ready
        } catch {
            state = .empty
        }
    }

    /// The dragged selection, else everything recognized.
    var text: String {
        let selected = interaction.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return selected.isEmpty ? transcript.trimmingCharacters(in: .whitespacesAndNewlines) : selected
    }
}

private struct LiveTextImage: UIViewRepresentable {
    let image: UIImage
    let interaction: ImageAnalysisInteraction

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}

    /// Take the space offered; a UIImageView's intrinsic size is the full photo (4032 px), which pushed the buttons off screen.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 300, height: proposal.height ?? 400)
    }
}

private struct QuoteScanSheet: View {
    let image: UIImage
    let onUse: (String) -> Void
    @StateObject private var model = LiveTextModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text(hint)
                .font(.custom("Palatino", size: 15))
                .foregroundColor(.yellow)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            LiveTextImage(image: image, interaction: model.interaction)
            HStack(spacing: 16) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.gray)
                Button("Use text") {
                    onUse(model.text)
                    dismiss()
                }
                .disabled(model.state != .ready)
                .foregroundColor(.white)
                .padding(.horizontal, 30).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                .opacity(model.state == .ready ? 1 : 0.4)
            }
            .padding(.bottom)
        }
        .padding(.top)
        .background(Color.black.ignoresSafeArea())
        .task { await model.analyze(image) }
    }

    private var hint: String {
        switch model.state {
        case .working: "Reading the photo…"
        case .ready: "Drag to select the quote, then tap Use text. Nothing selected uses all the text."
        case .empty: "No text found in this photo."
        case .unsupported: "Text capture isn't supported on this device."
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
