import Foundation

/// What you can do right now, decided entirely by the hub.
///
/// The pet renders these in the order given and reports back which was chosen. It never
/// works out what's actionable — that's semantics, and keeping it out of here is what
/// makes a second surface a hundred lines rather than a rewrite.
public struct Menu: Decodable, Equatable, Sendable {
  public struct Item: Decodable, Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
  }

  public let items: [Item]

  public static let empty = Menu(items: [])

  public init(items: [Item]) {
    self.items = items
  }
}
