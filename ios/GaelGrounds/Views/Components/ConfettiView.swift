import Combine
import SwiftUI

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let vx: CGFloat
    let vy: CGFloat
    let rotation: Double
    let rotationSpeed: Double
    let colorIndex: Int
    let delay: Double
    let w: CGFloat
    let h: CGFloat

    static func burst(count: Int = 200, width: CGFloat, height: CGFloat) -> [ConfettiParticle] {
        var result: [ConfettiParticle] = []
        for i in 0..<count {
            let fromBottom = i < count / 2
            result.append(ConfettiParticle(
                startX: CGFloat.random(in: 0...width),
                startY: fromBottom ? height : 0,
                vx: CGFloat.random(in: -190...190),
                vy: fromBottom
                    ? CGFloat.random(in: -1050 ... -450)
                    : CGFloat.random(in:  280  ...  750),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -420...420),
                colorIndex: Int.random(in: 0..<2),
                delay: Double.random(in: 0...0.35),
                w: CGFloat.random(in: 7...17),
                h: CGFloat.random(in: 4...10)
            ))
        }
        return result
    }
}

struct ConfettiOverlayView: View {
    let colors: [Color]

    @State private var particles: [ConfettiParticle] = []
    @State private var startTime = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                Canvas { ctx, _ in
                    let elapsed = timeline.date.timeIntervalSince(startTime)
                    let gravity: CGFloat = 700
                    for p in particles {
                        let t = CGFloat(elapsed - p.delay)
                        guard t > 0 && t < 4.5 else { continue }

                        let x = p.startX + p.vx * t
                        let y = p.startY + p.vy * t + 0.5 * gravity * t * t
                        let angle = Angle.degrees(p.rotation + p.rotationSpeed * Double(t))
                        let opacity = Double(max(0, min(1, 1.0 - (t - 2.8) / 1.7)))

                        ctx.drawLayer { lCtx in
                            lCtx.opacity = opacity
                            lCtx.translateBy(x: x, y: y)
                            lCtx.rotate(by: angle)
                            let color = colors[p.colorIndex % colors.count]
                            let rect = CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h)
                            lCtx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                        }
                    }
                }
            }
            .onAppear {
                particles = ConfettiParticle.burst(width: geo.size.width, height: geo.size.height)
                startTime = Date()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
