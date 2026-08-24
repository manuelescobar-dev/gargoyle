import CoreGraphics

/// Where the popover goes.
///
/// Pure, because it was landing somewhere different each time and the cause was measuring
/// the window before SwiftUI had finished laying it out — so the maths was done against
/// whatever size it happened to be last time.
public enum PopoverPlacement {
  private static let margin: CGFloat = 8

  public static func origin(for size: CGSize, near creature: CGRect, on screen: CGRect) -> CGPoint {
    // Centred on the creature, and rising from just inside it so it reads as coming out
    // of the creature rather than floating above it.
    var x = creature.midX - size.width / 2
    var y = creature.maxY - creature.height * 0.18

    x = min(max(x, screen.minX + margin), max(screen.minX + margin, screen.maxX - size.width - margin))
    // Clamped downward to fit, then floored — a popover taller than the screen should be
    // anchored on it rather than pushed off the bottom trying to show its top.
    y = min(y, screen.maxY - size.height - margin)
    y = max(y, screen.minY + margin)

    return CGPoint(x: x, y: y)
  }
}
