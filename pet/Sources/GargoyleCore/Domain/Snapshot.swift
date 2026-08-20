import Foundation

/// Mirrors `protocol/README.md`. The pet renders this and keeps nothing.
public struct Snapshot: Codable, Equatable, Sendable {
  public let state: State
  public let embers: [Ember]
  public let mood: Double
  public let blocked: Int

  public struct Ember: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let status: Status
  }

  /// The nine states. `unknown` never arrives over the wire — the pet enters it
  /// on its own when the hub is unreachable.
  public enum State: String, Codable, Sendable {
    case asleep, idle, working, done, failed, speaking, listening, unknown
    case needsYou = "needs-you"

    /// A hub newer than the pet must degrade, not crash.
    public init(from decoder: Decoder) throws {
      let raw = try decoder.singleValueContainer().decode(String.self)
      self = State(rawValue: raw) ?? .unknown
    }
  }

  public enum Status: String, Codable, Sendable {
    case running, blocked, done, unrecognised

    public init(from decoder: Decoder) throws {
      let raw = try decoder.singleValueContainer().decode(String.self)
      self = Status(rawValue: raw) ?? .unrecognised
    }
  }
}
