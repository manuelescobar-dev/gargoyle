import AppKit

/// Draws a `SlimePose`. Holds no rules of its own, same as the octopus.
@MainActor
public final class SlimeView: CreatureView, CreatureRenderer {
  private var pose: SlimePose = .from(CreatureInputs.from(nil))
  private var breath: Double = 0
  public var speech: String? {
    didSet {
      if speech != oldValue { needsDisplay = true }
    }
  }

  public func show(_ inputs: CreatureInputs, breath: Double) {
    let next = SlimePose.from(inputs)
    guard next != pose || breath != self.breath else { return }
    pose = next
    self.breath = breath
    needsDisplay = true
  }

  public func updateHitRegion() {
    opaqueRegion = bounds.insetBy(dx: bounds.width * 0.2, dy: bounds.height * 0.2)
  }

  private func skin(_ vitality: Double) -> NSColor {
    NSColor(
      calibratedHue: 0.78, saturation: 0.34 * vitality,
      brightness: 0.80 + (1 - vitality) * 0.1, alpha: 0.92
    )
  }

  public override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    let side = min(bounds.width, bounds.height)
    let radius = side * 0.20 * pose.size
    let centre = CGPoint(x: bounds.midX, y: bounds.midY - side * 0.05)
    let jiggle = sin(breath * 1.7) * pose.wobble
    let colour = skin(pose.vitality)

    // The body: a squashed blob that spreads as it flattens.
    let width = radius * (1 + pose.flatness * 0.45 + jiggle)
    let height = radius * (1 - pose.flatness * 0.30 - jiggle) * 1.18
    context.setFillColor(colour.cgColor)
    context.fillEllipse(
      in: CGRect(x: centre.x - width, y: centre.y - height, width: width * 2, height: height * 2)
    )

    // The pseudopod. No arms to extend, so it extends itself — same requirement, and it
    // has to leave the outline just as unmistakably.
    if pose.reach > 0 {
      let tip = CGPoint(x: centre.x + radius * 1.9 * pose.reach, y: centre.y + radius * 2.1 * pose.reach)
      let path = CGMutablePath()
      path.move(to: CGPoint(x: centre.x, y: centre.y + height * 0.6))
      path.addQuadCurve(to: tip, control: CGPoint(x: centre.x + radius * 0.2, y: centre.y + radius * 1.6))
      context.setStrokeColor(colour.cgColor)
      context.setLineWidth(radius * 0.42)
      context.setLineCap(.round)
      context.addPath(path)
      context.strokePath()

      let ember = radius * 0.30
      let bright = NSColor(calibratedRed: 1, green: 0.78, blue: 0.36, alpha: 1)
      context.setShadow(offset: .zero, blur: ember * 1.6, color: bright.cgColor)
      context.setFillColor(bright.cgColor)
      context.fillEllipse(in: CGRect(x: tip.x - ember, y: tip.y - ember, width: ember * 2, height: ember * 2))
      context.setShadow(offset: .zero, blur: 0, color: nil)
    }

    // Embers suspended inside rather than held. Load, without a single limb.
    for mote in pose.motes {
      let size = radius * 0.115
      let point = CGPoint(x: centre.x + mote.x * width, y: centre.y + mote.y * height)
      context.setFillColor(NSColor(calibratedRed: 1, green: 0.9, blue: 0.7, alpha: 0.9).cgColor)
      context.fillEllipse(in: CGRect(x: point.x - size, y: point.y - size, width: size * 2, height: size * 2))
    }

    drawEyes(centre: centre, width: width, height: height, context: context)
  }

  private func drawEyes(centre: CGPoint, width: Double, height: Double, context: CGContext) {
    guard pose.vitality > 0.3 else { return }
    let eye = width * 0.155
    let spacing = width * 0.27

    for side in [-1.0, 1.0] {
      let x = centre.x + spacing * side
      let y = centre.y + height * 0.34
      context.setFillColor(NSColor(calibratedWhite: 0.99, alpha: 1).cgColor)
      context.fillEllipse(in: CGRect(x: x - eye, y: y - eye, width: eye * 2, height: eye * 2))

      let pupil = eye * 0.5
      context.setFillColor(NSColor(calibratedWhite: 0.12, alpha: 1).cgColor)
      context.fillEllipse(
        in: CGRect(
          x: x + pose.pupil.x * (eye - pupil) - pupil,
          y: y + pose.pupil.y * (eye - pupil) - pupil,
          width: pupil * 2, height: pupil * 2
        )
      )
    }
  }
}
