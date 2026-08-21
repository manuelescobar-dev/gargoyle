import AppKit

/// What every creature is, before it's any particular creature.
///
/// Hit-testing against the body rather than the frame is most of what makes a floating
/// creature feel like it's sitting on the desktop instead of on top of it. An invisible
/// rectangle swallowing clicks is the fastest way to break that.
@MainActor
public class CreatureView: NSView {
  /// Where the creature actually is. Clicks outside it pass through to whatever's below.
  public var opaqueRegion: NSRect = .zero

  /// Called when the creature itself is clicked — not the empty space around it. Lives
  /// here rather than on any one creature, because clicking is the same everywhere.
  public var onClick: (() -> Void)?

  /// What it's saying, if anything. Nil most of the time, by design.
  public var speech: String? {
    didSet {
      guard speech != oldValue else { return }
      needsDisplay = true
    }
  }

  public override func mouseDown(with event: NSEvent) {
    onClick?()
  }

  public override func hitTest(_ point: NSPoint) -> NSView? {
    opaqueRegion.contains(convert(point, from: superview)) ? self : nil
  }

  /// A soft rounded bubble above the body. No tail, no border — it should read as the
  /// creature thinking out loud rather than a UI element docked to it.
  ///
  /// Here rather than on any one creature: the slime stored `speech` and never drew it, so
  /// choosing that creature made it mute. There is nothing creature-specific about a bubble.
  public func drawSpeech(above body: CGRect, in context: CGContext) {
    guard let text = speech, !text.isEmpty else { return }

    let font = NSFont.systemFont(ofSize: max(10, bounds.width * 0.058), weight: .medium)
    let string = NSAttributedString(
      string: text,
      attributes: [.font: font, .foregroundColor: NSColor(calibratedWhite: 0.16, alpha: 0.92)]
    )

    let padding = bounds.width * 0.05
    let maxTextWidth = bounds.width - padding * 4
    let measured = string.boundingRect(
      with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin]
    )
    let textSize = CGSize(
      width: ceil(min(measured.width, maxTextWidth)),
      height: ceil(measured.height)
    )

    let bubble = CGRect(
      x: bounds.midX - textSize.width / 2 - padding,
      y: body.maxY + bounds.height * 0.04,
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
    context.addPath(
      CGPath(
        roundedRect: bubble,
        cornerWidth: bubble.height / 2,
        cornerHeight: bubble.height / 2,
        transform: nil
      )
    )
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
}
