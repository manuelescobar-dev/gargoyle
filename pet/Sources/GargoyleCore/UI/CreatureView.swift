import AppKit

/// Hosts the creature and decides which clicks are ours.
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

  public override func mouseDown(with event: NSEvent) {
    onClick?()
  }

  public override func hitTest(_ point: NSPoint) -> NSView? {
    opaqueRegion.contains(convert(point, from: superview)) ? self : nil
  }
}
