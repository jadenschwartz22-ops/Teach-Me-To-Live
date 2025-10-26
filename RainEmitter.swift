import SwiftUI
import UIKit
import QuartzCore   // for CAEmitterLayer/CAEmitterCell

// MARK: - SwiftUI Wrapper
struct RainEmitter: UIViewRepresentable {
    var animate: Bool
    var maxBirthRate: Float = 200      // default “heavy rain”; use lower for drizzle

    func makeUIView(context: Context) -> RainContainerView {
        let view = RainContainerView()
        view.cell.birthRate = 0
        return view
    }

    func updateUIView(_ uiView: RainContainerView, context: Context) {
        if animate {
            uiView.startRainRampUp(maxBirth: maxBirthRate)
        }
    }
}

// MARK: - Underlying UIKit View
class RainContainerView: UIView {
    let emitter = CAEmitterLayer()
    let cell    = CAEmitterCell()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        // Configure the raindrop cell
        cell.name             = "raindrop"
        cell.birthRate         = 0         // start paused
        cell.lifetime          = 12.0
        cell.velocity          = 80
        cell.velocityRange     = 15
        cell.yAcceleration     = 8
        cell.emissionLongitude = .pi
        cell.scale             = 0.5
        cell.scaleRange        = 0.2
        cell.contents          = makeRaindropImage().cgImage
        cell.color             = UIColor.white.withAlphaComponent(0.15).cgColor

        // Configure the emitter
        emitter.emitterShape  = .line
        emitter.emitterMode   = .outline
        emitter.emitterCells  = [cell]
        layer.addSublayer(emitter)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        let dropSpawnOffset: CGFloat = 30
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -dropSpawnOffset)
        emitter.emitterSize     = CGSize(width: bounds.width, height: 0)
    }

    func startRainRampUp(maxBirth: Float) {
        // fade in the whole emitter
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue            = 0
        fade.toValue              = 0.8
        fade.duration             = 12.0
        fade.fillMode             = .forwards
        fade.isRemovedOnCompletion = false
        emitter.add(fade, forKey: "fadeIn")

        // ramp up birthRate to 'maxBirth'
        let birth = CAKeyframeAnimation(keyPath: "emitterCells.raindrop.birthRate")
        birth.values   = [2, 5, maxBirth]              // drizzle → light → your max
        birth.keyTimes = [0, 0.2, 1.0].map(NSNumber.init)
        birth.duration = 20.0
        birth.fillMode = .forwards
        birth.isRemovedOnCompletion = false
        emitter.add(birth, forKey: "rainBirth")

        // optional: adjust gravity if needed (reuse your previous gravity animation here)
    }

    private func makeRaindropImage() -> UIImage {
        let size = CGSize(width: 2, height: 10)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
