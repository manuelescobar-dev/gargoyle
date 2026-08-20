import AppKit

/// The window the creature lives in.
///
/// `.nonactivatingPanel` plus `becomesKeyOnlyIfNeeded` is the combination Electron
/// can't reproduce: clicking the creature doesn't pull focus out of whatever you were
/// typing in, but a text field inside it still takes keys when you click into it.
@MainActor
public final class CreaturePanel: NSPanel {
  public init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 96, height: 96),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    level = .floating
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false  // a creature has no box; a shadow would draw one
    becomesKeyOnlyIfNeeded = true
    isMovableByWindowBackground = true
    // Follows you between Spaces and sits over fullscreen apps, without being dragged
    // along when you switch — it belongs to the screen, not to a workspace.
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
  }

  public override var canBecomeMain: Bool { false }
  /// Only when something inside actually needs the keyboard.
  public override var canBecomeKey: Bool { true }
}
