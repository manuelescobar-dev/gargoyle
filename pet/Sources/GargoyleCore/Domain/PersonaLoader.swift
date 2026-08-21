import Foundation

/// Finds the creature's persona on disk.
///
/// Walks up from the executable looking for `creatures/<name>/persona.md`, which works
/// from a dev build. When it can't find one it falls back to a small built-in voice —
/// a mute creature would be worse than a briefly repetitive one.
///
/// TODO: bundle personas as package resources so an installed build doesn't depend on
/// sitting inside the repo.
public enum PersonaLoader {
  public static func load(creature: String = "octopus") -> Persona {
    var directory = URL(fileURLWithPath: CommandLine.arguments.first ?? ".")
      .deletingLastPathComponent()

    for _ in 0..<8 {
      let candidate = directory.appending(path: "creatures/\(creature)/persona.md")
      if let text = try? String(contentsOf: candidate, encoding: .utf8),
         let persona = try? Persona(markdown: text) {
        return persona
      }
      directory.deleteLastPathComponent()
    }

    return (try? Persona(markdown: fallback)) ?? (try! Persona(markdown: "---\nname: ?\n---"))
  }

  private static let fallback = """
    ---
    name: Tako
    ---
    ## Lines

    ### needs-you
    - "this one's been waiting."
    - "someone wants a word."
    - "blocked. has been for a bit."

    ### failed
    - "that one didn't make it."
    - "failed. the suite, not you."
    - "hm. no."

    ### idle
    - "nothing's on fire."
    - "all quiet. suspiciously so."
    - "that's the lot of them."

    ### busy
    - "that's a lot of arms."
    - "running out of arms here."
    - "we're doing six now, apparently."

    ### greeting
    - "oh — you're back."
    - "hello again."
    - "there you are."
    """
}
