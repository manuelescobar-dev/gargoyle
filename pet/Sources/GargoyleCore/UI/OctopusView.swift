import AppKit

/// Draws an `OctopusPose`. Holds no rules of its own — every decision about what the
/// creature does lives in the pose.
@MainActor
public final class OctopusView: CreatureView, CreatureRenderer {
  /// Satisfies `CreatureRenderer` — the octopus keeps its own richer pose behind it.
  public func show(_ inputs: CreatureInputs, breath: Double) {
    // Settle toward the new pose rather than cutting to it, then lay the small motions on
    // top. States that snap are the tell that something is a sprite.
    settled = .lerp(settled, .from(inputs), Self.easing)
    pose = settled.animated(by: life.advance(to: breath))
    self.breath = breath
  }

  /// Slow enough to read as movement, quick enough that a blocked agent doesn't feel delayed.
  private static let easing = 0.14
  private var settled: OctopusPose = .from(CreatureInputs.from(nil))

  public func updateHitRegion() {
    opaqueRegion = bounds.insetBy(dx: bounds.width * 0.12, dy: bounds.height * 0.12)
  }

  private var life = Liveliness()

  public var pose: OctopusPose = .from(CreatureInputs.from(nil)) {
    didSet {
      guard pose != oldValue else { return }  // nothing changed, nothing repaints
      needsDisplay = true
    }
  }

  /// Advanced by the host only while there's motion worth showing.
  public var breath: Double = 0 {
    didSet { needsDisplay = true }
  }

  /// What it's saying, if anything. Nil most of the time, by design.
  public var speech: String? {
    didSet {
      guard speech != oldValue else { return }
      needsDisplay = true
    }
  }

  private var mantleRadius: Double { min(bounds.width, bounds.height) * 0.145 }
  /// The head sits high; big head, small body is most of what makes a thing read as cute.
  /// Sits below centre, leaving the upper third for whatever it has to say.
  private var headCenter: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY - bounds.height * 0.06) }
  /// Arms emerge from under the head, not from inside it.
  private var center: CGPoint { CGPoint(x: bounds.midX, y: headCenter.y - mantleRadius * 0.5) }

  // Calm slate → warm and busy. Real octopuses signal with colour, so the palette is the
  // animal doing what it does rather than a status light bolted to its side.
  private func skin(_ mood: Double, vitality: Double) -> NSColor {
    NSColor(
      calibratedHue: 0.52 - mood * 0.44,
      saturation: (0.42 + mood * 0.24) * vitality,
      brightness: 0.86 - mood * 0.06 + (1 - vitality) * 0.06,
      alpha: 1
    )
  }

  public override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let mood = pose.mantleSquash
    let color = skin(mood, vitality: pose.vitality)
    let r = mantleRadius
    let breathe = 1 + sin(breath) * 0.035

    for arm in pose.arms { draw(arm, from: center, radius: r, color: color, in: context) }

    // Head last, so the arms tuck behind it.
    let squash = 1 - pose.mantleSquash * 0.16
    let head = CGRect(
      x: headCenter.x - r * breathe,
      y: headCenter.y - r * squash * breathe,
      width: r * 2 * breathe,
      height: r * 2 * squash * breathe
    )
    context.setFillColor(color.cgColor)
    context.fillEllipse(in: head)

    drawEyes(in: head, context: context)
    drawMouth(in: head, context: context)
    if let speech { drawSpeech(speech, above: head, context: context) }
  }

  private func draw(
    _ arm: OctopusPose.Arm, from origin: CGPoint, radius r: Double,
    color: NSColor, in context: CGContext
  ) {
    let length = r * 2.1 * arm.reach
    let tip = CGPoint(
      x: origin.x + cos(arm.baseAngle) * length,
      y: origin.y + sin(arm.baseAngle) * length
    )
    // Pushed perpendicular to the arm, which is what gives it a coil rather than a spoke.
    let perpendicular = arm.baseAngle + .pi / 2
    let control = CGPoint(
      x: origin.x + cos(arm.baseAngle) * length * 0.55 + cos(perpendicular) * length * arm.curl,
      y: origin.y + sin(arm.baseAngle) * length * 0.55 + sin(perpendicular) * length * arm.curl
    )

    // Filled and tapered rather than stroked. A uniform-width line reads as a stub;
    // thick at the shoulder thinning to a point is what makes it an arm.
    let baseWidth = r * (arm.isPresenting ? 0.62 : 0.58)
    context.setFillColor(color.cgColor)
    context.addPath(taperedArm(from: origin, control: control, to: tip, baseWidth: baseWidth))
    context.fillPath()

    // Filled separately: an ellipse added to the same path winds the opposite way, and
    // non-zero winding then punches a hole in the arm instead of rounding it off.
    let cap = baseWidth * 0.70 / 2
    context.fillEllipse(in: CGRect(x: tip.x - cap, y: tip.y - cap, width: cap * 2, height: cap * 2))

    if arm.holdsEmber { drawEmber(at: tip, radius: r, urgent: arm.isPresenting, in: context) }
  }

  /// Walks the curve, offsetting perpendicular by a width that thins toward the tip.
  private func taperedArm(
    from start: CGPoint, control: CGPoint, to end: CGPoint, baseWidth: Double
  ) -> CGPath {
    let steps = 14
    var left: [CGPoint] = []
    var right: [CGPoint] = []

    for step in 0...steps {
      let t = Double(step) / Double(steps)
      let inv = 1 - t
      let point = CGPoint(
        x: inv * inv * start.x + 2 * inv * t * control.x + t * t * end.x,
        y: inv * inv * start.y + 2 * inv * t * control.y + t * t * end.y
      )
      // Tangent of the quadratic, for the perpendicular.
      let dx = 2 * inv * (control.x - start.x) + 2 * t * (end.x - control.x)
      let dy = 2 * inv * (control.y - start.y) + 2 * t * (end.y - control.y)
      let len = max(hypot(dx, dy), 0.0001)
      let nx = -dy / len, ny = dx / len

      let width = baseWidth * (1 - t * 0.30) / 2
      left.append(CGPoint(x: point.x + nx * width, y: point.y + ny * width))
      right.append(CGPoint(x: point.x - nx * width, y: point.y - ny * width))
    }

    let path = CGMutablePath()
    path.addLines(between: left + right.reversed())
    path.closeSubpath()
    return path
  }

  private func drawEmber(at point: CGPoint, radius r: Double, urgent: Bool, in context: CGContext) {
    let size = r * (urgent ? 0.34 : 0.24)
    let core = urgent
      ? NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.36, alpha: 1)
      : NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.72, alpha: 0.85)

    context.setShadow(offset: .zero, blur: urgent ? size * 1.6 : size * 0.7, color: core.cgColor)
    context.setFillColor(core.cgColor)
    context.fillEllipse(
      in: CGRect(x: point.x - size, y: point.y - size, width: size * 2, height: size * 2)
    )
    context.setShadow(offset: .zero, blur: 0, color: nil)
  }

  /// Two eyes, wide-set and low. One eye reads as a cyclops; two low ones read as a face
  /// you'd want on your desk. Big relative to the head, which is the other half of the trick.
  private func drawEyes(in head: CGRect, context: CGContext) {
    guard pose.eyeOpen > 0.02 else {
      drawClosedEyes(in: head, context: context)
      return
    }

    let w = head.width * 0.27
    let h = w * 1.06 * pose.eyeOpen
    let spacing = head.width * 0.20
    let y = head.midY - head.height * 0.06

    for side in [-1.0, 1.0] {
      let cx = head.midX + spacing * side
      context.setFillColor(NSColor(calibratedWhite: 0.99, alpha: 1).cgColor)
      context.fillEllipse(in: CGRect(x: cx - w / 2, y: y - h / 2, width: w, height: h))

      guard pose.eyeOpen > 0.35 else { continue }
      let pupil = w * 0.52
      let px = cx + pose.pupil.x * (w - pupil) * 0.45
      let py = y + pose.pupil.y * (h - pupil) * 0.45
      context.setFillColor(NSColor(calibratedWhite: 0.11, alpha: 1).cgColor)
      context.fillEllipse(in: CGRect(x: px - pupil / 2, y: py - pupil / 2, width: pupil, height: pupil))

      // A catchlight. Two small white dots are most of what makes eyes look alive.
      let glint = pupil * 0.34
      context.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.95).cgColor)
      context.fillEllipse(
        in: CGRect(x: px - pupil * 0.06, y: py + pupil * 0.12, width: glint, height: glint)
      )
    }
  }

  /// A soft rounded bubble above the head. No tail, no border — it should feel like the
  /// creature thinking out loud, not a UI element docked to it.
  private func drawSpeech(_ text: String, above head: CGRect, context: CGContext) {
    let font = NSFont.systemFont(ofSize: max(10, bounds.width * 0.058), weight: .medium)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor(calibratedWhite: 0.16, alpha: 0.92),
    ]
    let string = NSAttributedString(string: text, attributes: attributes)

    let padding = bounds.width * 0.05
    let maxTextWidth = bounds.width - padding * 4
    let measured = string.boundingRect(
      with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin]
    )
    let textSize = CGSize(width: ceil(min(measured.width, maxTextWidth)), height: ceil(measured.height))

    let bubble = CGRect(
      x: bounds.midX - textSize.width / 2 - padding,
      y: head.maxY + bounds.height * 0.04,
      width: textSize.width + padding * 2,
      height: textSize.height + padding * 1.5
    )
    guard bubble.maxY < bounds.maxY, bubble.minX > bounds.minX else { return }

    context.setShadow(
      offset: CGSize(width: 0, height: -1),
      blur: 6,
      color: NSColor(calibratedWhite: 0, alpha: 0.16).cgColor
    )
    context.setFillColor(NSColor(calibratedWhite: 0.99, alpha: 0.97).cgColor)
    context.addPath(CGPath(roundedRect: bubble, cornerWidth: bubble.height / 2,
                           cornerHeight: bubble.height / 2, transform: nil))
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)

    // Drawn into a bounded rect so a long line wraps instead of running off the bubble.
    string.draw(
      with: CGRect(
        x: bubble.midX - textSize.width / 2,
        y: bubble.midY - textSize.height / 2,
        width: textSize.width,
        height: textSize.height
      ),
      options: [.usesLineFragmentOrigin]
    )
  }

  /// A small smile. Cheap, and it's the difference between a creature that tolerates you
  /// and one that's pleased you're there.
  private func drawMouth(in head: CGRect, context: CGContext) {
    guard pose.eyeOpen > 0.35 else { return }
    let w = head.width * 0.17
    let y = head.midY - head.height * 0.32
    let droop = pose.vitality < 0.5  // when it doesn't know, it isn't smiling

    let path = CGMutablePath()
    path.move(to: CGPoint(x: head.midX - w / 2, y: y))
    path.addQuadCurve(
      to: CGPoint(x: head.midX + w / 2, y: y),
      control: CGPoint(x: head.midX, y: y + (droop ? w * 0.5 : -w * 0.55))
    )
    context.setStrokeColor(NSColor(calibratedWhite: 0.22, alpha: 0.55).cgColor)
    context.setLineWidth(max(1.1, head.width * 0.028))
    context.setLineCap(.round)
    context.addPath(path)
    context.strokePath()
  }

  /// Asleep: two soft downward arcs rather than a blank face.
  private func drawClosedEyes(in head: CGRect, context: CGContext) {
    let w = head.width * 0.22
    let spacing = head.width * 0.20
    let y = head.midY - head.height * 0.04

    context.setStrokeColor(NSColor(calibratedWhite: 0.28, alpha: 0.75).cgColor)
    context.setLineWidth(max(1.2, head.width * 0.035))
    context.setLineCap(.round)
    for side in [-1.0, 1.0] {
      let cx = head.midX + spacing * side
      let path = CGMutablePath()
      path.move(to: CGPoint(x: cx - w / 2, y: y))
      path.addQuadCurve(to: CGPoint(x: cx + w / 2, y: y), control: CGPoint(x: cx, y: y - w * 0.42))
      context.addPath(path)
    }
    context.strokePath()
  }
}
