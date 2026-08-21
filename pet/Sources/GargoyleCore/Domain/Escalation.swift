/// The top of the interruption ladder, and the only rung that leaves the screen.
///
/// The hub decides *whether* something has been ignored long enough to earn this. All this
/// does is make sure it happens once — a notification that repeats every frame would be
/// exactly the thing the ladder exists to prevent.
public struct Escalation: Sendable {
  private var alreadyNotified = false

  public init() {}

  public mutating func shouldNotify(_ level: Snapshot.Attention?) -> Bool {
    guard level == .notify else {
      // Dropping back down re-arms it: the next escalation is a new thing being ignored,
      // not the same one shouting twice.
      alreadyNotified = false
      return false
    }

    if alreadyNotified { return false }
    alreadyNotified = true
    return true
  }
}
