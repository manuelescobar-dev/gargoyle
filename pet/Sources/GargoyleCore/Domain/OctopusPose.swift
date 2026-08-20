import CoreGraphics
import Foundation

/// The octopus's shape for a given moment, as pure geometry.
///
/// Everything the design depends on lives here rather than in the drawing code, so the
/// rules — one arm per agent, exactly one asking arm, unknown never resembling idle —
/// are testable without a screen.
///
/// Drawn rather than authored in Rive because the mechanic is arithmetic: arms are a
/// function of `load` and `blocked`, so every in-between state comes free. See decisions/0002.
public struct OctopusPose: Equatable, Sendable {
  public struct Arm: Equatable, Sendable {
    /// Where it attaches, radians. 0 is right, π/2 is up.
    public let baseAngle: Double
    /// How far it extends, roughly in mantle-radii.
    public let reach: Double
    /// Which way it coils, and how hard. Signed away from the middle so the fan opens.
    public let curl: Double
    public let holdsEmber: Bool
    /// The one holding an ember out toward you.
    public let isPresenting: Bool
  }

  public let arms: [Arm]
  /// 0 round and calm, 1 tense and flattened.
  public let mantleSquash: Double
  /// Where the pupil sits, as a fraction of the eye. Never leaves it.
  public let pupil: CGPoint
  public let eyeOpen: Double
  /// 1 is a creature that knows what's going on; low is drained of colour, for `unknown`.
  public let vitality: Double

  private static let armCount = 8
  /// Arms fan across the lower half, the way one hangs off a ledge.
  private static let arc = (start: Double.pi * 1.08, sweep: Double.pi * 0.84)

  public static func from(_ inputs: CreatureInputs) -> OctopusPose {
    let state = inputs.state
    let asleep = state == 0
    let unknown = state == 8
    let holding = min(inputs.load, armCount)

    // Central, so the arm that asks for you is the most visible one it has.
    let presentingIndex = inputs.blocked > 0 ? armCount / 2 : -1

    let baseReach: Double =
      asleep ? 0.34
      : unknown ? 0.62   // slack and searching, not tucked away like sleep
      : holding > 0 ? 0.72 : 0.60

    let arms = (0..<armCount).map { i -> Arm in
      let t = Double(i) / Double(armCount - 1)
      let presenting = i == presentingIndex

      // The asking arm lifts up and out, into the empty space above the fan. Reaching
      // further *downward* would just make it longer among other long things — and it
      // would carry the ember off the bottom of the creature, which is the one pixel
      // that has to be seen.
      let presentAngle = Double.pi * 0.30

      // Outer arms sit shorter than the middle ones, which is what makes a fan read as
      // a fan rather than a rake. The ripple keeps it off a perfect curve.
      let fan = 1 - pow(abs(t - 0.5) * 2, 2) * 0.28
      let ripple = sin(Double(i) * 1.7) * 0.05

      // When we don't know, the arms fall slack toward vertical instead of fanning out.
      // A narrowed silhouette survives being shrunk to 48px, where a paler colour or a
      // half-closed eye simply disappears — and looking calm while blind is the one
      // thing this creature must never do.
      let straightDown = Double.pi * 1.5
      let spread = arc.start + arc.sweep * t
      let angle = unknown ? spread + (straightDown - spread) * 0.72 : spread

      return Arm(
        baseAngle: presenting ? presentAngle : angle,
        // 1.9× clears the mantle outright — peripheral vision needs the outline broken,
        // and a slightly longer arm would just look like a stretch.
        reach: presenting ? baseReach * 1.55 : baseReach * fan + ripple,
        // Curls away from the middle, so the arms open like an umbrella instead of
        // alternating and crossing into loops. Magnitude grows toward the outside.
        curl: (t < 0.5 ? -1 : 1) * (abs(t - 0.5) * 2) * (unknown ? 0.42 : 0.20 + inputs.mood * 0.16),
        // The asking arm always has one: it is, by definition, holding a light out to you.
        holdsEmber: i < holding || presenting,
        isPresenting: presenting
      )
    }

    return OctopusPose(
      arms: arms,
      mantleSquash: min(1, inputs.mood * 0.6 + Double(holding) / 12.0),
      pupil: asleep ? .zero : CGPoint(x: inputs.gazeX * 0.7, y: inputs.gazeY * 0.7),
      eyeOpen: asleep ? 0.05 : unknown ? 0.55 : 1.0,
      vitality: unknown ? 0.22 : asleep ? 0.6 : 1.0
    )
  }
}
