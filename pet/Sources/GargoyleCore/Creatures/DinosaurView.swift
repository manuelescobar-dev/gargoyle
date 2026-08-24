import AppKit

/// Draws a `DinosaurPose`. Holds no rules of its own, same as the others.
@MainActor
public final class DinosaurView: CreatureView, CreatureRenderer {
  private var pose: DinosaurPose = .from(CreatureInputs.from(nil))
  private var breath: Double = 0

  public func show(_ inputs: CreatureInputs, breath: Double) {
    let next = DinosaurPose.from(inputs)
    guard next != pose || breath != self.breath else { return }
    pose = next
    self.breath = breath
    needsDisplay = true
  }

  public func updateHitRegion() {
    opaqueRegion = bounds.insetBy(dx: bounds.width * 0.12, dy: bounds.height * 0.18)
  }

  /// Mossy green, warming as it gets busy. The plates carry the heat, so mood reads as the
  /// animal doing something rather than as a status light stuck to its side.
  private func hide(_ vitality: Double) -> NSColor {
    NSColor(
      calibratedHue: 0.29, saturation: 0.34 * vitality,
      brightness: 0.62 + (1 - vitality) * 0.24, alpha: 1
    )
  }

  public override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    let side = min(bounds.width, bounds.height)
    let unit = side * 0.085
    let skin = hide(pose.vitality)
    let wobble = sin(breath * 1.4) * pose.sway

    // Body sits low; head rides in front, and drops as it tires or gives up.
    let hipY = bounds.midY - side * 0.10 + (pose.headDrop > 0.8 ? -unit * 0.5 : 0)
    let hip = CGPoint(x: bounds.midX + unit * 0.7, y: hipY)
    let headCentre = CGPoint(
      x: bounds.midX - unit * 2.9,
      y: hipY + unit * (1.6 - pose.headDrop * 1.5) + wobble * unit
    )

    drawTail(from: hip, unit: unit, skin: skin, in: context)
    drawLegs(hip: hip, unit: unit, skin: skin, in: context)

    // Body over the legs and tail, then plates on top of it — sunk into the body they
    // showed as stubs, which made three agents look like two.
    context.setFillColor(skin.cgColor)
    context.fillEllipse(
      in: CGRect(x: hip.x - unit * 2.3, y: hip.y - unit * 1.15,
                 width: unit * 4.2, height: unit * 2.4)
    )
    drawPlates(hip: hip, head: headCentre, unit: unit, in: context)
    drawArm(hip: hip, unit: unit, skin: skin, in: context)

    let head = CGRect(x: headCentre.x - unit * 1.35, y: headCentre.y - unit * 1.15,
                      width: unit * 2.7, height: unit * 2.3)
    // Neck, drawn as a thick line so it follows the head wherever it hangs.
    context.setStrokeColor(skin.cgColor)
    context.setLineWidth(unit * 1.15)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: hip.x - unit * 1.6, y: hip.y + unit * 0.4))
    context.addLine(to: CGPoint(x: headCentre.x + unit * 0.4, y: headCentre.y - unit * 0.2))
    context.strokePath()

    context.setFillColor(skin.cgColor)
    context.fillEllipse(in: head)
    drawFace(in: head, context: context)

    drawSpeech(above: CGRect(x: bounds.minX, y: max(head.maxY, hip.y + unit * 2.4),
                             width: bounds.width, height: 1), in: context)
  }

  /// The tail does the asking. Resting it curls low behind; blocked it rears up and over,
  /// which changes the outline the way an octopus arm leaving the body does.
  private func drawTail(from hip: CGPoint, unit: Double, skin: NSColor, in context: CGContext) {
    let lift = pose.tailLift
    let wag = pose.presenting ? sin(breath * 3.0) * unit * 0.55 : 0

    let root = CGPoint(x: hip.x + unit * 1.2, y: hip.y + unit * 0.1)
    let tip = CGPoint(
      x: hip.x + unit * (3.7 - lift * 1.6),
      y: hip.y + unit * (lift * 5.2 - 0.7) + wag
    )
    let control = CGPoint(
      x: hip.x + unit * (3.9 + lift * 0.5),
      y: hip.y + unit * (lift * 2.2 - 0.4)
    )

    // Tapered by walking the curve, the way the octopus's arms are — a uniform stroke
    // reads as a pipe stuck on the back.
    let steps = 12
    var left: [CGPoint] = []
    var right: [CGPoint] = []
    for step in 0...steps {
      let t = Double(step) / Double(steps)
      let inv = 1 - t
      let point = CGPoint(
        x: inv * inv * root.x + 2 * inv * t * control.x + t * t * tip.x,
        y: inv * inv * root.y + 2 * inv * t * control.y + t * t * tip.y
      )
      let dx = 2 * inv * (control.x - root.x) + 2 * t * (tip.x - control.x)
      let dy = 2 * inv * (control.y - root.y) + 2 * t * (tip.y - control.y)
      let len = max(hypot(dx, dy), 0.0001)
      let w = unit * 0.62 * (1 - t * 0.55)
      left.append(CGPoint(x: point.x - dy / len * w, y: point.y + dx / len * w))
      right.append(CGPoint(x: point.x + dy / len * w, y: point.y - dx / len * w))
    }

    let path = CGMutablePath()
    path.addLines(between: left + right.reversed())
    path.closeSubpath()
    context.setFillColor(skin.cgColor)
    context.addPath(path)
    context.fillPath()

    // Capped separately: an ellipse in the same path winds the other way and punches a
    // hole rather than rounding the tip. Same trap the octopus's arms hit.
    let cap = unit * 0.62 * 0.45 / 2
    context.fillEllipse(in: CGRect(x: tip.x - cap, y: tip.y - cap, width: cap * 2, height: cap * 2))

    guard pose.presenting else { return }
    let ember = unit * 0.5
    let bright = NSColor(calibratedRed: 1, green: 0.78, blue: 0.36, alpha: 1)
    context.setShadow(offset: .zero, blur: ember * 1.8, color: bright.cgColor)
    context.setFillColor(bright.cgColor)
    context.fillEllipse(in: CGRect(x: tip.x - ember, y: tip.y - ember,
                                   width: ember * 2, height: ember * 2))
    context.setShadow(offset: .zero, blur: 0, color: nil)
  }

  private func drawLegs(hip: CGPoint, unit: Double, skin: NSColor, in context: CGContext) {
    let sprawl = pose.headDrop > 0.8 ? 0.5 : 1.0  // lying down tucks them under
    context.setFillColor(skin.cgColor)
    for offset in [-1.3, 0.9] {
      context.fillEllipse(
        in: CGRect(x: hip.x + unit * offset - unit * 0.45,
                   y: hip.y - unit * (1.0 + 0.9 * sprawl),
                   width: unit * 0.95, height: unit * 1.3 * sprawl + unit * 0.4)
      )
    }
  }

  /// Comically small, which is most of why a dinosaur is cute for free.
  private func drawArm(hip: CGPoint, unit: Double, skin: NSColor, in context: CGContext) {
    context.setFillColor(skin.cgColor)
    context.fillEllipse(
      in: CGRect(x: hip.x - unit * 2.2, y: hip.y - unit * 0.2,
                 width: unit * 0.9, height: unit * 0.42)
    )
  }

  /// One plate per agent, tallest at the shoulder. Load, without growing a new limb.
  private func drawPlates(hip: CGPoint, head: CGPoint, unit: Double, in context: CGContext) {
    guard !pose.plates.isEmpty else { return }
    let warm = NSColor(calibratedRed: 1, green: 0.82, blue: 0.45, alpha: 0.95)
    let span = unit * 2.9

    for (index, height) in pose.plates.enumerated() {
      let along = pose.plates.count > 1 ? Double(index) / Double(pose.plates.count - 1) : 0.5
      let x = hip.x + unit * 1.5 - span * along
      let base = hip.y + unit * 1.05

      let path = CGMutablePath()
      path.move(to: CGPoint(x: x - unit * 0.5, y: base))
      path.addLine(to: CGPoint(x: x, y: base + unit * 2.1 * height))
      path.addLine(to: CGPoint(x: x + unit * 0.5, y: base))
      path.closeSubpath()

      context.setShadow(offset: .zero, blur: unit * 0.7, color: warm.cgColor)
      context.setFillColor(warm.cgColor)
      context.addPath(path)
      context.fillPath()
      context.setShadow(offset: .zero, blur: 0, color: nil)
    }
  }

  private func drawFace(in head: CGRect, context: CGContext) {
    guard pose.eyeOpen > 0.15 else {
      context.setStrokeColor(NSColor(calibratedWhite: 0.25, alpha: 0.7).cgColor)
      context.setLineWidth(max(1, head.width * 0.05))
      context.setLineCap(.round)
      let y = head.midY + head.height * 0.1
      context.move(to: CGPoint(x: head.midX - head.width * 0.22, y: y))
      context.addQuadCurve(to: CGPoint(x: head.midX + head.width * 0.02, y: y),
                           control: CGPoint(x: head.midX - head.width * 0.1, y: y - head.height * 0.09))
      context.strokePath()
      return
    }

    let eye = head.width * 0.20
    let cx = head.midX - head.width * 0.10
    let cy = head.midY + head.height * 0.14

    context.setFillColor(NSColor(calibratedWhite: 0.99, alpha: 1).cgColor)
    context.fillEllipse(in: CGRect(x: cx - eye, y: cy - eye, width: eye * 2, height: eye * 2))

    let pupil = eye * 0.5
    let px = cx + pose.pupil.x * (eye - pupil)
    let py = cy + pose.pupil.y * (eye - pupil)
    context.setFillColor(NSColor(calibratedWhite: 0.11, alpha: 1).cgColor)
    context.fillEllipse(in: CGRect(x: px - pupil, y: py - pupil, width: pupil * 2, height: pupil * 2))

    // A catchlight. Two dots of white are most of what makes an eye look alive.
    let glint = pupil * 0.6
    context.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.95).cgColor)
    context.fillEllipse(in: CGRect(x: px - pupil * 0.1, y: py + pupil * 0.2,
                                   width: glint, height: glint))
  }
}
