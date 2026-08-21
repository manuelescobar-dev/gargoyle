import Foundation

/// The creature's voice, read from its `persona.md`.
///
/// Personality is voice, not volume: this decides *how* something already worth saying
/// gets said. It never decides that something should be said — that's the hub's call.
///
/// Without OpenClaw these pools are the whole voice, and they're deterministic: no model,
/// no network, no latency. With OpenClaw the same file becomes a system prompt.
public struct Persona: Sendable {
  public let name: String
  private let pools: [String: [String]]
  private var lastSaid: [String: String] = [:]
  /// Remaining lines this cycle. A bag rather than a random pick, so the whole pool gets
  /// used instead of two favourites coming up over and over.
  private var bag: [String: [String]] = [:]

  public init(markdown: String) throws {
    var name = "unnamed"
    var pools: [String: [String]] = [:]
    var situation: String?

    for raw in markdown.components(separatedBy: .newlines) {
      let line = raw.trimmingCharacters(in: .whitespaces)

      if line.hasPrefix("name:") {
        name = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
      } else if line.hasPrefix("### ") {
        situation = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
      } else if line.hasPrefix("## ") {
        situation = nil  // any other heading ends the current pool
      } else if line.hasPrefix("- "), let key = situation {
        let quoted = line.dropFirst(2).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
        if !quoted.isEmpty { pools[key, default: []].append(String(quoted)) }
      }
    }

    self.name = name
    self.pools = pools
  }

  public func lines(for situation: String) -> [String] {
    pools[situation] ?? []
  }

  /// `nil` when there's nothing written for this situation — saying nothing is always
  /// better than saying something that doesn't fit.
  public mutating func line(for situation: String) -> String? {
    let pool = lines(for: situation)
    guard !pool.isEmpty else { return nil }

    if bag[situation]?.isEmpty ?? true {
      var refilled = pool.shuffled()
      // Don't let a new cycle open with the line the last one closed on.
      if refilled.count > 1, refilled.first == lastSaid[situation] {
        refilled.swapAt(0, refilled.count - 1)
      }
      bag[situation] = refilled
    }

    let chosen = bag[situation]!.removeFirst()
    lastSaid[situation] = chosen
    return chosen
  }
}
