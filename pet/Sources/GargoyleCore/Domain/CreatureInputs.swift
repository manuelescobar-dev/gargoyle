import CoreGraphics
import Foundation

/// The inputs every `.riv` exposes, per `creatures/README.md`.
///
/// This is the seam between the hub's semantics and a creature's anatomy. The hub says
/// `needs-you`; how that looks is the creature's business.
public struct CreatureInputs: Equatable, Sendable {
  /// Index into the nine documented states. **Order is a contract with every creature
  /// ever authored** — appending is safe, reordering is not.
  public let state: Int
  public let load: Int
  public let blocked: Int
  public let mood: Double
  public var gazeX: Double = 0
  public var gazeY: Double = 0

  private static let order: [Snapshot.State] = [
    .asleep, .idle, .working, .needsYou, .done, .failed, .speaking, .listening, .unknown,
  ]

  public static func from(_ snapshot: Snapshot?) -> CreatureInputs {
    guard let snapshot else {
      return CreatureInputs(state: index(of: .unknown), load: 0, blocked: 0, mood: 0)
    }
    return CreatureInputs(
      state: index(of: snapshot.state),
      load: snapshot.embers.count,
      blocked: snapshot.blocked,
      mood: snapshot.mood
    )
  }

  private static func index(of state: Snapshot.State) -> Int {
    order.firstIndex(of: state) ?? order.count - 1
  }

  /// Where the creature should be looking, as a direction rather than a distance.
  ///
  /// Continuous on purpose: discrete look-left / look-right poses are the tell that
  /// something is a sprite rather than a creature.
  public static func gaze(cursor: CGPoint, from home: CGPoint, reach: Double) -> (x: Double, y: Double) {
    guard reach > 0 else { return (0, 0) }
    let clamp = { (v: Double) in max(-1, min(1, v)) }
    return (
      clamp(Double(cursor.x - home.x) / reach),
      clamp(Double(cursor.y - home.y) / reach)
    )
  }
}
