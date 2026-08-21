import Foundation
import Testing
@testable import GargoyleCore

private let sample = """
---
name: Tako
temperament: [dry, unbothered]
speaks: sparingly
---

## Voice
Says the shortest true thing and stops.

## Lines

### needs-you
- "this one's been waiting."
- "someone wants a word."
- "blocked. has been for a bit."

### done
- "that's finished."
- "one down."
- "done. cleanly, even."
"""

@Test("a persona knows its name and its lines")
func parsesPersona() throws {
  let persona = try Persona(markdown: sample)
  #expect(persona.name == "Tako")
  #expect(persona.lines(for: "needs-you").count == 3)
  #expect(persona.lines(for: "done").contains("one down."))
}

@Test("an unknown situation is silence, not a crash")
func unknownSituationIsSilent() throws {
  var persona = try Persona(markdown: sample)
  #expect(persona.lines(for: "brooding").isEmpty)
  #expect(persona.line(for: "brooding") == nil, "saying nothing beats saying something wrong")
}

// Repetition is the fastest way to make something feel dead.
@Test("it never says the same thing twice in a row")
func neverRepeatsBackToBack() throws {
  var persona = try Persona(markdown: sample)
  var previous: String?

  for _ in 0..<40 {
    let line = persona.line(for: "needs-you")
    #expect(line != nil)
    #expect(line != previous, "heard the same line twice running")
    previous = line
  }
}

@Test("it uses the whole pool, not two favourites")
func usesTheWholePool() throws {
  var persona = try Persona(markdown: sample)
  var heard = Set<String>()
  for _ in 0..<40 { heard.insert(persona.line(for: "done")!) }
  #expect(heard.count == 3)
}

@Test("a single-line situation still works rather than deadlocking")
func toleratesAShallowPool() throws {
  var persona = try Persona(markdown: "---\nname: X\n---\n## Lines\n\n### done\n- \"only one.\"\n")
  #expect(persona.line(for: "done") == "only one.")
  #expect(persona.line(for: "done") == "only one.", "it must not loop forever hunting for variety")
}

@Test("the real octopus persona parses and is deep enough to not repeat")
func shippedPersonaIsUsable() throws {
  var root = URL(fileURLWithPath: #filePath)
  for _ in 0..<4 { root.deleteLastPathComponent() }
  var persona = try Persona(
    markdown: String(contentsOf: root.appending(path: "creatures/octopus/persona.md"), encoding: .utf8)
  )
  _ = persona.line(for: "done")

  #expect(persona.name == "Tako")
  for situation in ["needs-you", "done", "failed", "greeting", "idle", "busy"] {
    #expect(
      persona.lines(for: situation).count >= 3,
      "\(situation) has fewer than three lines — it'll start repeating"
    )
  }
}
