import Foundation

/// What the pet currently believes, and the only logic it is allowed to own.
///
/// Deliberately a value type with no networking in it, so the behaviour that matters —
/// what happens when the hub goes away — is testable without a socket.
public struct HubState: Sendable {
  /// `nil` means unknown. Not idle, not stale: unknown.
  public private(set) var latest: Snapshot?

  private var situation: String?

  private struct Tagged: Decodable { let t: String?; let situation: String? }

  public init() {}

  /// Returns whether anything changed, so the caller can skip repainting.
  @discardableResult
  public mutating func received(_ data: Data) -> Bool {
    // A single bad frame on a live connection isn't a dead hub — the last snapshot was
    // true a moment ago and nothing has said otherwise. Only an actual drop means unknown.
    // The hub says *that* something is worth saying and about what; the creature's
    // persona decides how it sounds.
    if let tagged = try? JSONDecoder().decode(Tagged.self, from: data), tagged.t == "bubble" {
      situation = tagged.situation
      return false  // nothing about the world changed
    }

    guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return false }
    guard snapshot != latest else { return false }
    latest = snapshot
    return true
  }

  /// The socket closed. This is decisions/0003's one exception: the pet decides this
  /// itself and immediately, because whatever would have told it is what disappeared.
  public mutating func dropped() {
    latest = nil
  }

  /// Hands over a pending situation exactly once — otherwise the creature would repeat
  /// the same line on every frame.
  public mutating func takeSituation() -> String? {
    defer { situation = nil }
    return situation
  }
}
