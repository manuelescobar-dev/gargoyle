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

  public func show(
    summary: String,
    menu: Menu,
    request: (id: String, summary: String)?,
    nudge: (id: String, text: String, replyable: Bool)?,
    near creature: NSRect,
    onChoose: @escaping (String) -> Void,
    onDecide: @escaping (String, Bool) -> Void,
    onReply: @escaping (String, String) -> Void,
    onSay: @escaping (String) -> Void
  ) {
    self.onChoose = onChoose

    let content = PopoverContent(
      summary: summary,
      items: menu.items,
      request: request.map { PopoverContent.Request(id: $0.id, summary: $0.summary) },
      // Always present. A field that only appears when the creature asked something means
      // you can answer it but never start.
      nudge: nudge.flatMap { $0.replyable ? PopoverContent.Nudge(id: $0.id, text: $0.text) : nil },
      canSpeakFirst: true,
      choose: { [weak self] id in
        self?.onChoose(id)
        self?.hide()
      },
      decide: { [weak self] id, approved in
        onDecide(id, approved)
        self?.hide()
      },
      reply: { [weak self] id, text in
        onReply(id, text)
        self?.hide()
      },
      say: { [weak self] text in
        onSay(text)
        self?.hide()
      }
    )

    let view = NSHostingView(rootView: content)
    contentView = view
    hosting = view

    // Lay it out before measuring. `fittingSize` on a fresh hosting view isn't final until
    // SwiftUI has run a pass, and reading the window frame first gave whatever size the
    // popover happened to be last time — which is why it landed somewhere new each click.
    view.layoutSubtreeIfNeeded()
    let size = view.fittingSize

    let placed = PopoverPlacement.origin(
      for: size,
      near: creature,
      on: NSScreen.main?.visibleFrame ?? creature
    )
    // One call, so the window is never briefly the old size at the new position.
    setFrame(NSRect(origin: placed, size: size), display: false)

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
  struct Request { let id: String; let summary: String }
  struct Nudge { let id: String; let text: String }

  let summary: String
  let items: [Menu.Item]
  let request: Request?
  let nudge: Nudge?
  let canSpeakFirst: Bool
  let choose: (String) -> Void
  let decide: (String, Bool) -> Void
  let reply: (String, String) -> Void
  let say: (String) -> Void

  @State private var answer = ""
  @FocusState private var answerFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let request { permission(request) }
      if let nudge { asking(nudge) }
      if nudge == nil, canSpeakFirst { speakFirst() }

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
    .frame(width: 260)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  /// A question from one of your own sources, in its words. The field is the whole point:
  /// a question you can't answer is just a notification, which is the thing we aren't building.
  @ViewBuilder
  private func asking(_ nudge: Nudge) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(nudge.text)
        .font(.system(size: 13, weight: .medium))
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)

      TextField("", text: $answer, prompt: Text("…"))
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 12))
        .focused($answerFocused)
        .onSubmit {
          let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !trimmed.isEmpty else { return }
          reply(nudge.id, trimmed)
        }
    }
    .padding(.horizontal, 14)
    .padding(.top, 12)
    .padding(.bottom, 10)
    .onAppear { answerFocused = true }

    Divider().padding(.horizontal, 10)
  }

  /// Saying something unprompted.
  ///
  /// You always start it, it answers once, and it never follows up — which is what keeps
  /// *personality is voice, not volume* true while still letting you talk to the thing.
  @ViewBuilder
  private func speakFirst() -> some View {
    TextField("", text: $answer, prompt: Text("say something…"))
      .textFieldStyle(.roundedBorder)
      .font(.system(size: 12))
      .focused($answerFocused)
      .onSubmit {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        say(trimmed)
      }
      .padding(.horizontal, 14)
      .padding(.top, 12)
      .padding(.bottom, 10)
      .onAppear { answerFocused = true }

    Divider().padding(.horizontal, 10)
  }

  /// Sits at the top because it's the only thing here with a clock running on it — the hub
  /// gives up after twenty seconds and hands the question back to the terminal.
  @ViewBuilder
  private func permission(_ request: Request) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Wants to")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)

      Text(request.summary)
        .font(.system(size: 13, weight: .medium))
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 8) {
        Button("Approve") { decide(request.id, true) }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        Button("Deny") { decide(request.id, false) }
          .buttonStyle(.bordered)
          .controlSize(.small)
      }
    }
    .padding(.horizontal, 14)
    .padding(.top, 12)
    .padding(.bottom, 10)

    Divider().padding(.horizontal, 10)
  }
}
