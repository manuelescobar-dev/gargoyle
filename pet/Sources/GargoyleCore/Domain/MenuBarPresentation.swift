import Foundation

/// What the menu bar should display for a given snapshot.
///
/// Pure — no AppKit, no networking. That's what lets the branchy part be tested
/// without launching an app, and it keeps the rendering layer free of decisions.
public struct MenuBarPresentation: Equatable, Sendable {
  /// SF Symbol name. One family, varying weight — a stable silhouette is what your eye learns.
  public let symbol: String
  /// Shown beside the symbol. Empty when there's no number worth showing.
  public let text: String
  /// The first line of the dropdown.
  public let summary: String
  /// One line per ember: `worktree · status`.
  public let rows: [String]

  /// `nil` means the hub is unreachable. That is not the same as quiet, and it must
  /// never look the same — see decisions/0003.
  public static func from(_ snapshot: Snapshot?) -> MenuBarPresentation {
    guard let snapshot else { return unreachable }

    let running = snapshot.embers.filter { $0.status == .running }.count
    let rows = snapshot.embers.map { "\($0.label) · \($0.status.rawValue)" }

    switch snapshot.state {
    case .needsYou:
      return MenuBarPresentation(
        symbol: "circle.fill",
        text: "\(snapshot.blocked)",
        summary: snapshot.blocked == 1 ? "1 agent needs you" : "\(snapshot.blocked) agents need you",
        rows: rows
      )

    case .working:
      return MenuBarPresentation(
        symbol: "circle.dotted",
        text: "\(running)",
        summary: "\(running) running",
        rows: rows
      )

    case .done:
      return MenuBarPresentation(symbol: "checkmark.circle", text: "", summary: "just finished", rows: rows)

    case .failed:
      return MenuBarPresentation(symbol: "xmark.circle", text: "", summary: "something failed", rows: rows)

    // A zero would be noise. Nothing running means nothing to say.
    case .idle, .asleep, .speaking, .listening:
      return MenuBarPresentation(symbol: "circle", text: "", summary: "all quiet", rows: rows)

    // The hub told us it doesn't know, which is as honest as us deciding it ourselves.
    case .unknown:
      return unreachable
    }
  }

  private static let unreachable = MenuBarPresentation(
    symbol: "questionmark.circle",
    text: "",
    summary: "hub unreachable",
    rows: []
  )
}
