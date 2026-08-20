import AppKit

/// Draws an `OctopusPose`. Holds no rules of its own — every decision about what the
/// creature does lives in the pose.
@MainActor
public final class OctopusView: CreatureView {
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

  private var mantleRadius: Double { min(bounds.width, bounds.height) * 0.125 }
  /// Arms hang from under the mantle, not from its middle.
  private var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY + mantleRadius * 0.2) }

  // Calm slate → warm and busy. Real octopuses signal with colour, so the palette is the
  // animal doing what it does rather than a status light bolted to its side.
  private func skin(_ mood: Double, vitality: Double) -> NSColor {
    NSColor(
      calibratedHue: 0.60 - mood * 0.52,
      saturation: (0.28 + mood * 0.34) * vitality,
      brightness: 0.62 + mood * 0.20 + (1 - vitality) * 0.18,
      alpha: 1
    )
  }

  public override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let mood = pose.mantleSquash
    let color = skin(mood, vitality: pose.vitality)
    let r = mantleRadius
    let breathe = 1 + sin(breath) * 0.03

    for arm in pose.arms { draw(arm, from: center, radius: r, color: color, in: context) }

    // Mantle last, so the arms tuck behind it.
    let squash = 1 - pose.mantleSquash * 0.22
    let mantle = CGRect(
      x: center.x - r * breathe, y: center.y - r * squash * breathe,
      width: r * 2 * breathe, height: r * 2 * squash * breathe
    )
    context.setFillColor(color.cgColor)
    context.fillEllipse(in: mantle)

    drawEye(in: mantle, context: context)
  }

  private func draw(
    _ arm: OctopusPose.Arm, from origin: CGPoint, radius r: Double,
    color: NSColor, in context: CGContext
  ) {
    let length = r * 3.5 * arm.reach
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
    context.setFillColor(color.cgColor)
    context.addPath(taperedArm(from: origin, control: control, to: tip,
                               baseWidth: r * (arm.isPresenting ? 0.78 : 0.66)))
    context.fillPath()

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

      let width = baseWidth * pow(1 - t, 0.85) / 2
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

  private func drawEye(in mantle: CGRect, context: CGContext) {
    guard pose.eyeOpen > 0.02 else { return }
    let w = mantle.width * 0.30
    let h = w * pose.eyeOpen
    let origin = CGPoint(x: mantle.midX - w / 2, y: mantle.midY + mantle.height * 0.06 - h / 2)

    context.setFillColor(NSColor(calibratedWhite: 0.97, alpha: 1).cgColor)
    context.fillEllipse(in: CGRect(x: origin.x, y: origin.y, width: w, height: h))

    guard pose.eyeOpen > 0.4 else { return }
    let pupilSize = w * 0.44
    context.setFillColor(NSColor(calibratedWhite: 0.09, alpha: 1).cgColor)
    context.fillEllipse(
      in: CGRect(
        x: origin.x + w / 2 - pupilSize / 2 + pose.pupil.x * (w - pupilSize) / 2,
        y: origin.y + h / 2 - pupilSize / 2 + pose.pupil.y * (h - pupilSize) / 2,
        width: pupilSize, height: pupilSize
      )
    )
  }
}
