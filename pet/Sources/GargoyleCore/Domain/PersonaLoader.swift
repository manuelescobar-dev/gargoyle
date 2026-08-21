import Foundation

/// Finds the creature's persona.
///
/// Inside the app bundle first, since that's where it lives once installed. Failing that,
/// walks up from the executable to find the repo, which is what a dev build needs. Failing
/// both, a small built-in voice — a mute creature would be worse than a briefly repetitive one.
public enum PersonaLoader {
  public static func load(creature: String = "octopus") -> Persona {
    for url in candidates(for: creature) {
      if let text = try? String(contentsOf: url, encoding: .utf8),
         let persona = try? Persona(markdown: text) {
        Trace.log("persona: loaded \(url.path)")
        return persona
      }
    }

    Trace.log("persona: none found on disk, using the built-in voice")
    return (try? Persona(markdown: fallback)) ?? (try! Persona(markdown: "---\nname: ?\n---"))
  }

  private static func candidates(for creature: String) -> [URL] {
    var urls: [URL] = []

    // Installed: shipped inside the bundle.
    if let resources = Bundle.main.resourceURL {
      urls.append(resources.appending(path: "creatures/\(creature)/persona.md"))
    }

    // Dev build: somewhere above the executable is the repo.
    var directory = URL(fileURLWithPath: CommandLine.arguments.first ?? ".")
      .deletingLastPathComponent()
    for _ in 0..<8 {
      urls.append(directory.appending(path: "creatures/\(creature)/persona.md"))
      directory.deleteLastPathComponent()
    }

    return urls
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
