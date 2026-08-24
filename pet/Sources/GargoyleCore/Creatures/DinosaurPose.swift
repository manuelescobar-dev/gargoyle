import CoreGraphics
import Foundation

/// A creature with limbs that don't scale.
///
/// The octopus has an arm per agent and never has to think about running out. The slime
/// has no anatomy to run out of. A dinosaur has four legs, two useless arms and one tail,
/// so load goes on its back — a row of plates along the spine — and the tail does the
/// asking, because a raised tail changes the outline the way an extended arm does.
public struct DinosaurPose: Equatable, Sendable {
  /// One per agent, front to back. Height is a fraction of the body.
  public let plates: [Double]
  /// How far the tail rears up. 0 is resting, 1 is over the body.
  public let tailLift: Double
  /// Whether it's holding an ember out on the tail tip.
  public let presenting: Bool
  /// How far the head hangs. 0 is up and alert, 1 is on the ground.
  public let headDrop: Double
  /// Idle movement. Near zero when it's attending to you.
  public let sway: Double
  public let pupil: CGPoint
  public let eyeOpen: Double
  public let vitality: Double

  /// It doesn't grow a longer spine to fit more agents.
  private static let maxPlates = 8

  public static func from(_ inputs: CreatureInputs) -> DinosaurPose {
    let state = inputs.state
    let asleep = state == 0
    let unknown = state == 8
    let failed = state == 5
    let attending = state == 6 || state == 7
    let blocked = inputs.blocked > 0

    // Plates get shorter as they go back, so a full spine reads as a ridge rather than a
    // wall, and taller with mood so a busy creature looks busier.
    let carrying = min(inputs.load, maxPlates)
    let plates = (0..<carrying).map { index -> Double in
      let along = carrying > 1 ? Double(index) / Double(carrying - 1) : 0
      return (0.55 + inputs.mood * 0.25) * (1 - along * 0.45)
    }

    return DinosaurPose(
      plates: unknown ? [] : plates,
      // One gesture however many are blocked. Two tails would be flailing, and it only has
      // the one anyway.
      tailLift: blocked ? 0.95 : unknown ? 0.02 : asleep ? 0.05 : 0.18,
      presenting: blocked,
      // Sleep puts the head on the ground; not knowing slumps it; failure droops it.
      headDrop: asleep ? 0.92 : unknown ? 0.68 : failed ? 0.45 : attending ? 0.04 : 0.18,
      sway: asleep ? 0.01 : attending ? 0.02 : unknown ? 0.04 : 0.12 + inputs.mood * 0.06,
      pupil: asleep ? .zero : CGPoint(x: inputs.gazeX * 0.7, y: inputs.gazeY * 0.6),
      eyeOpen: asleep ? 0.05 : unknown ? 0.5 : 1.0,
      vitality: unknown ? 0.2 : asleep ? 0.6 : 1.0
    )
  }
}
