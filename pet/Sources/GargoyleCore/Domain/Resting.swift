import CoreGraphics
import Foundation

/// When the creature should sleep, and where it should sit.
///
/// Both were rules before they were code — *it costs nothing when it's doing nothing* and
/// *home, not wandering* — and both went unenforced for a while. Pure so they can be
/// argued with in a test rather than by leaving a laptop open overnight.
public enum Resting {
  /// Long enough that a coffee doesn't put it to sleep. Overridable so the behaviour can
  /// actually be exercised — `asleep` sat unreachable for a while precisely because
  /// checking it meant leaving a laptop alone for five minutes.
  public static var defaultIdleSeconds: Double {
    ProcessInfo.processInfo.environment["GARGOYLE_IDLE_SECONDS"].flatMap(Double.init) ?? 300
  }

  /// Seconds since you last did anything.
  ///
  /// Not `kCGAnyInputEventType`: that counts system-generated events too and reads as
  /// zero forever, which is why `asleep` stayed unreachable. Measured instead as the
  /// most recent of the things a person actually does.
  public static func idleSeconds() -> Double {
    let inputs: [CGEventType] = [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]
    return inputs
      .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
      .min() ?? 0
  }

  public static func shouldSleep(idleSeconds: Double, after: Double, blocked: Int = 0) -> Bool {
    // Something has been waiting for you. Dozing off in front of it would be the creature
    // showing calm it hasn't got.
    if blocked > 0 { return false }
    return idleSeconds > after
  }

  /// Where to put the creature: where you left it, pulled back into view if that spot no
  /// longer exists. Displays get unplugged and resolutions change.
  public static func home(remembered: CGPoint?, on screen: CGRect, size: CGSize) -> CGPoint {
    guard let remembered else {
      return CGPoint(x: screen.maxX - size.width - 24, y: screen.minY + 24)
    }

    return CGPoint(
      x: min(max(remembered.x, screen.minX), screen.maxX - size.width),
      y: min(max(remembered.y, screen.minY), screen.maxY - size.height)
    )
  }
}
