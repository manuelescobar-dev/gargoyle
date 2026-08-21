import AppKit

/// What every creature has to be.
///
/// The seam is `CreatureInputs` — nine states, load, blocked, mood, gaze — and nothing
/// else. A creature decides entirely for itself what those look like; it never learns what
/// an agent is, or that Claude Code exists.
///
/// This is what makes the roster real rather than aspirational. See creatures/README.md.
@MainActor
public protocol CreatureRenderer: CreatureView {
  /// Show this. Called on every frame the creature is visible.
  func show(_ inputs: CreatureInputs, breath: Double)

  /// Where the body actually is, so clicks on empty pixels pass through.
  func updateHitRegion()
}

/// The creatures that ship. Picking one is a name, not a code change.
public enum Creatures {
  nonisolated public static let names = ["octopus", "slime"]

  @MainActor
  public static func make(_ name: String, frame: NSRect) -> any CreatureRenderer {
    switch name {
    case "slime": return SlimeView(frame: frame)
    default: return OctopusView(frame: frame)
    }
  }

  /// `GARGOYLE_CREATURE=slime`. A setting, not a rebuild.
  nonisolated public static func chosen() -> String {
    let named = ProcessInfo.processInfo.environment["GARGOYLE_CREATURE"] ?? "octopus"
    return names.contains(named) ? named : "octopus"
  }
}
