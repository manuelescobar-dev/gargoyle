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
  nonisolated public static let names = ["octopus", "slime", "dinosaur"]

  @MainActor
  public static func make(_ name: String, frame: NSRect) -> any CreatureRenderer {
    switch name {
    case "slime": return SlimeView(frame: frame)
    case "dinosaur": return DinosaurView(frame: frame)
    default: return OctopusView(frame: frame)
    }
  }

  /// Which creature to be.
  ///
  /// `gargoyle configure` writes this into `~/.gargoyle/config.json`, so the choice
  /// survives a restart and is somewhere you can see it. The environment variable stays as
  /// an override for trying one out without committing to it.
  nonisolated public static func chosen() -> String {
    let named = ProcessInfo.processInfo.environment["GARGOYLE_CREATURE"] ?? configured()
    return names.contains(named) ? named : "octopus"
  }

  nonisolated private static func configured() -> String {
    let path = ProcessInfo.processInfo.environment["GARGOYLE_CONFIG"]
      ?? NSHomeDirectory() + "/.gargoyle/config.json"

    guard let data = FileManager.default.contents(atPath: path),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let creature = json["creature"] as? String
    else { return "octopus" }

    return creature
  }
}
