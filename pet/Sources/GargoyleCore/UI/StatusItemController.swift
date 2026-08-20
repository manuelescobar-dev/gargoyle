import AppKit

/// Owns the status item and applies presentations to it. Decides nothing.
@MainActor
public final class StatusItemController {
  private let item: NSStatusItem
  private var current: MenuBarPresentation?

  public init() {
    item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  }

  /// No-op when nothing changed, so an idle machine does no UI work at all.
  public func apply(_ presentation: MenuBarPresentation) {
    guard presentation != current else { return }
    current = presentation

    item.button?.image = NSImage(
      systemSymbolName: presentation.symbol,
      accessibilityDescription: presentation.summary
    )
    item.button?.title = presentation.text.isEmpty ? "" : " \(presentation.text)"
    item.menu = menu(for: presentation)
  }

  private func menu(for presentation: MenuBarPresentation) -> NSMenu {
    let menu = NSMenu()
    menu.addItem(disabled(presentation.summary))

    if !presentation.rows.isEmpty {
      menu.addItem(.separator())
      // Not actionable yet — jumping to a waiting agent's terminal is M2.
      for row in presentation.rows { menu.addItem(disabled(row)) }
    }

    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Quit Gargoyle",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    return menu
  }

  private func disabled(_ title: String) -> NSMenuItem {
    let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    entry.isEnabled = false
    return entry
  }
}
