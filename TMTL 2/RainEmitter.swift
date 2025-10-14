import SwiftUI
import QuartzCore

struct RainEmitter: UIViewRepresentable {
    var animate: Bool
    var maxBirthRate: Float = 150

    func makeUIView(context: Context) -> RainContainerView {
        let view = RainContainerView()
        view.cell.birthRate = 0
        return view
    }

    func updateUIView(_ uiView: RainContainerView, context: Context) {
        if animate {
            uiView.startIfNeeded(maxBirth: maxBirthRate)   // ← only starts once
        } else {
            uiView.stop()                                   // ← pauses when hidden
        }
    }
}

class RainContainerView: UIView {
    let emitter = CAEmitterLayer()
    let cell = CAEmitterCell()
    private var didStart = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        cell.name = "raindrop"
        cell.birthRate = 0
        cell.lifetime = 12.0
        cell.velocity = 80
        cell.velocityRange = 15
        cell.yAcceleration = 8
        cell.emissionLongitude = .pi
        cell.scale = 0.5
        cell.scaleRange = 0.2
        cell.contents = makeRaindropImage().cgImage
        cell.color = UIColor.white.withAlphaComponent(0.15).cgColor

        emitter.emitterShape = .line
        emitter.emitterMode = .outline
        emitter.emitterCells = [cell]
        layer.addSublayer(emitter)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        let dropSpawnOffset: CGFloat = 30
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -dropSpawnOffset)
        emitter.emitterSize = CGSize(width: bounds.width, height: 0)
    }

    // MARK: control
    func startIfNeeded(maxBirth: Float) {
        guard !didStart else { return }
        didStart = true
        startRainRampUp(maxBirth: maxBirth)
    }

    func stop() {
        didStart = false
        emitter.removeAnimation(forKey: "fadeIn")
        emitter.removeAnimation(forKey: "rainBirth")
        emitter.setValue(0, forKeyPath: "emitterCells.raindrop.birthRate")
        cell.birthRate = 0
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() } // auto-pause if view gets detached
    }

    // MARK: existing animation code (unchanged)
    func startRainRampUp(maxBirth: Float) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 0.8
        fade.duration = 12.0
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        emitter.add(fade, forKey: "fadeIn")

        let birth = CAKeyframeAnimation(keyPath: "emitterCells.raindrop.birthRate")
        birth.values = [0, maxBirth * 0.1, maxBirth * 0.5, maxBirth] as [NSNumber]
        birth.keyTimes = [0.0, 0.6, 0.9, 1.0] as [NSNumber]
        birth.duration = 30.0
        birth.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeOut)
        ]
        birth.fillMode = .forwards
        birth.isRemovedOnCompletion = false
        emitter.add(birth, forKey: "rainBirth")
    }

    private func makeRaindropImage() -> UIImage {
        let size = CGSize(width: 2, height: 10)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
