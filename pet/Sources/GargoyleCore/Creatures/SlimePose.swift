import CoreGraphics
import Foundation

/// A creature with no limbs, which is the point of it.
///
/// The octopus's mechanic is one arm per agent. The slime can't do that, so it has to
/// satisfy the same nine states some other way — embers suspended inside it, a pseudopod
/// where an arm would be. If the contract survives that, the states are semantic rather
/// than a description of how an octopus happens to work.
public struct SlimePose: Equatable, Sendable {
  /// Embers, suspended rather than held. Position is a fraction of the body.
  public let motes: [CGPoint]
  /// 0 calm and round, 1 spread thin.
  public let flatness: Double
  /// Overall size — it swells with what it's carrying.
  public let size: Double
  /// How far a pseudopod reaches beyond the outline. 0 unless it needs you.
  public let reach: Double
  /// How much it jiggles.
  public let wobble: Double
  public let pupil: CGPoint
  public let vitality: Double

  private static let maxMotes = 8

  public static func from(_ inputs: CreatureInputs) -> SlimePose {
    let state = inputs.state
    let asleep = state == 0
    let unknown = state == 8
    let attending = state == 6 || state == 7
    let carrying = min(inputs.load, maxMotes)

    // Scattered through the lower body on a fixed spiral — deterministic, so an unchanged
    // snapshot doesn't make the motes drift about, and kept clear of the eyes, which sit
    // in the upper half.
    // Laid out across the lower body rather than scattered: seven overlapping dots read as
    // a smudge, seven spaced ones read as seven. Two rows once there are more than four,
    // and clear of the eyes, which sit in the upper half.
    let motes = (0..<carrying).map { index -> CGPoint in
      let perRow = carrying > 4 ? (carrying + 1) / 2 : carrying
      let row = index / perRow
      let column = index % perRow
      let spread = perRow > 1 ? Double(column) / Double(perRow - 1) - 0.5 : 0

      return CGPoint(
        x: spread * 0.86,
        // Lower row sits further down, and the arc follows the curve of the body.
        y: -0.34 - Double(row) * 0.32 + (0.25 - spread * spread) * 0.30
      )
    }

    return SlimePose(
      motes: motes,
      // Sleep puddles it; not knowing makes it slump; being busy pulls it tight.
      flatness: asleep ? 0.66 : unknown ? 0.42 : min(0.22, inputs.mood * 0.18),
      size: 0.62 + Double(carrying) * 0.045,
      // Nothing to extend but itself. Same requirement, different anatomy.
      reach: inputs.blocked > 0 ? 0.85 : 0,
      wobble: asleep ? 0.02 : attending ? 0.04 : 0.10 + inputs.mood * 0.10,
      pupil: asleep ? .zero : CGPoint(x: inputs.gazeX * 0.6, y: inputs.gazeY * 0.6),
      vitality: unknown ? 0.2 : asleep ? 0.55 : 1.0
    )
  }
}
