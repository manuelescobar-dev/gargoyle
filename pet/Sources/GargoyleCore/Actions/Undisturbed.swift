import AppKit

/// Whether now is plainly not the moment.
///
/// macOS Focus state is not readable: `~/Library/DoNotDisturb/` is TCC-protected, the
/// format is undocumented and changes between releases, and asking for Full Disk Access so
/// a mascot can know whether you're in Do Not Disturb is a bad trade.
///
/// So we read the thing we *can* read, for free: whether the frontmost app is filling the
/// screen. Presenting, watching, or deep in something fullscreen is the case the principle
/// was really about, and window bounds need no permission at all.
public enum Undisturbed {
  /// A little slack for rounding, but not enough to catch a merely maximised window —
  /// leaving the menu bar visible is the difference between working and presenting.
  private static let slack: CGFloat = 2

  public static func covers(window: CGRect?, screen: CGRect) -> Bool {
    guard let window, screen.width > 0, screen.height > 0 else { return false }
    return window.width >= screen.width - slack && window.height >= screen.height - slack
  }

  /// Bounds of the frontmost app's largest on-screen window. No permission required —
  /// only window *titles* and images are gated, not geometry.
  public static func frontmostWindow() -> CGRect? {
    guard let front = NSWorkspace.shared.frontmostApplication else { return nil }

    let listed = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
    ) as? [[String: Any]] ?? []

    return listed
      .filter { ($0[kCGWindowOwnerPID as String] as? Int32) == front.processIdentifier }
      .compactMap { entry -> CGRect? in
        guard let b = entry[kCGWindowBounds as String] as? [String: CGFloat],
              let w = b["Width"], let h = b["Height"], let x = b["X"], let y = b["Y"]
        else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
      }
      .max { $0.width * $0.height < $1.width * $1.height }
  }

  public static func now() -> Bool {
    covers(window: frontmostWindow(), screen: NSScreen.main?.frame ?? .zero)
  }
}
