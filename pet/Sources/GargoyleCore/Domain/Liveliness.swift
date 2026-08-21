import Foundation

/// The small motions that make a drawing feel like a creature: blinking, arms drifting,
/// the asking arm beckoning rather than holding still.
///
/// Kept apart from `OctopusPose` because the pose answers *what state is it in* and this
/// answers *how does it move*. The pose stays pure and derived; this owns the clock.
public struct Liveliness: Sendable {
  public struct Frame: Sendable {
    public let time: Double
    public let justBlinked: Bool
    public let eyeOpen: Double
    public let breath: Double
    public let presentingWave: Double

    /// A per-arm drift. Phase-shifted so they never move in lockstep.
    public func sway(arm index: Int) -> Double {
      let phase = Double(index) * 2.39996  // golden angle: no two arms share a rhythm
      return sin(time * 1.15 + phase) * 0.055 + sin(time * 0.47 + phase * 1.7) * 0.03
    }
  }

  private var nextBlink: Double = 3.1
  private var blinkStart: Double = -1
  private var seed: Double = 0.61803

  private static let blinkDuration = 0.14

  public init() {}

  public mutating func advance(to time: Double) -> Frame {
    var justBlinked = false

    if time >= nextBlink {
      blinkStart = time
      justBlinked = true
      // Cheap deterministic scatter — no RNG, and never the same gap twice running.
      seed = (seed * 4.11 + 0.31).truncatingRemainder(dividingBy: 1)
      nextBlink = time + 2.2 + seed * 5.5
    }

    let sinceBlink = time - blinkStart
    let blinking = sinceBlink >= 0 && sinceBlink < Self.blinkDuration
    // Down and back up, rather than a hard cut to shut.
    let eyeOpen = blinking ? abs(cos(sinceBlink / Self.blinkDuration * .pi)) : 1

    return Frame(
      time: time,
      justBlinked: justBlinked,
      eyeOpen: max(0.06, eyeOpen),
      breath: sin(time * 1.05) * 0.5 + 0.5,
      presentingWave: sin(time * 2.3)
    )
  }
}
