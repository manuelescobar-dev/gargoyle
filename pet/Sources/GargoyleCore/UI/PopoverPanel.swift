import AppKit
import SwiftUI

/// What you can do right now, shown when you click the creature.
///
/// A panel rather than an `NSPopover`: a popover wants a conventional window to anchor to
/// and fights a borderless floating one. This is positioned by hand so it reads as coming
/// *out of* the creature rather than being docked beside it.
@MainActor
public final class PopoverPanel: NSPanel {
  private var onChoose: (String) -> Void = { _ in }
  private var hosting: NSHostingView<PopoverContent>?

  public init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 240, height: 10),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    level = .floating
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true  // unlike the creature, this *is* a surface, so it casts one
    becomesKeyOnlyIfNeeded = true
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    hidesOnDeactivate = false
  }

  public override var canBecomeKey: Bool { true }

  public func show(summary: String, menu: Menu, near creature: NSRect, onChoose: @escaping (String) -> Void) {
    self.onChoose = onChoose

    let content = PopoverContent(summary: summary, items: menu.items) { [weak self] id in
      self?.onChoose(id)
      self?.hide()
    }

    let view = NSHostingView(rootView: content)
    view.frame.size = view.fittingSize
    contentView = view
    hosting = view
    setContentSize(view.fittingSize)

    // Sits above the creature, nudged so it appears to rise out of it.
    var origin = NSPoint(
      x: creature.midX - frame.width / 2,
      y: creature.maxY - creature.height * 0.18
    )
    if let screen = NSScreen.main {
      origin.x = min(max(origin.x, screen.visibleFrame.minX + 8),
                     screen.visibleFrame.maxX - frame.width - 8)
      origin.y = min(origin.y, screen.visibleFrame.maxY - frame.height - 8)
    }
    setFrameOrigin(origin)

    alphaValue = 0
    orderFront(nil)
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.14
      animator().alphaValue = 1
    }
  }

  public func hide() {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.10
      animator().alphaValue = 0
    } completionHandler: { [weak self] in
      self?.orderOut(nil)
    }
  }

  public override func cancelOperation(_ sender: Any?) { hide() }  // Escape
  public override func resignKey() { super.resignKey(); hide() }
}

struct PopoverContent: View {
  let summary: String
  let items: [Menu.Item]
  let choose: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(summary)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, items.isEmpty ? 12 : 8)

      ForEach(items) { item in
        Button { choose(item.id) } label: {
          Text(item.label)
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      Divider().padding(.horizontal, 10).padding(.top, items.isEmpty ? 0 : 4)

      Button { NSApp.terminate(nil) } label: {
        Text("Quit Gargoyle")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 14)
          .padding(.vertical, 7)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Color.clear.frame(height: 6)
    }
    .frame(width: 240)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
