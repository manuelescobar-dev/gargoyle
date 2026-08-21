import AppKit

/// Puts the creature on screen and keeps it current.
@MainActor
public final class CreatureController {
  private let panel = CreaturePanel()
  private let popover = PopoverPanel()
  private var menu: Menu = .empty
  private var summary = "all quiet"
  /// Set by the app so a chosen item gets reported back to the hub.
  public var onAction: (String) -> Void = { _ in }
  /// Reports an answered permission request. `true` approves.
  public var onDecide: (String, Bool) -> Void = { _, _ in }
  private var request: (id: String, summary: String)?
  private var nudge: (id: String, text: String, replyable: Bool)?
  /// Reports an answered nudge.
  public var onReply: (String, String) -> Void = { _, _ in }
  private let view: OctopusView
  private var inputs = CreatureInputs.from(nil)
  private var life = Liveliness()
  private var persona = PersonaLoader.load()
  private var speechUntil: Double = -1
  private var settled: OctopusPose
  private var clock: Double = 0
  private var link: CADisplayLink?

  /// How long a line stays up. Long enough to read on a glance, short enough that it
  /// isn't still sitting there next time you look over.
  private static let speechDuration: Double = 6

  /// How fast it settles into a new pose. Slow enough to read as movement, quick enough
  /// that a blocked agent doesn't feel delayed.
  private static let easing = 0.14

  /// How far away the cursor can be and still be worth looking at.
  private static let gazeReach: Double = 600

  public init() {
    settled = .from(CreatureInputs.from(nil))
    view = OctopusView(frame: panel.contentLayoutRect)
    view.autoresizingMask = [.width, .height]
    panel.contentView = view
    view.onClick = { [weak self] in self?.toggle() }
    moveHome()
    panel.orderFront(nil)
    apply(nil)
    startAnimating()
  }

  /// A question waiting on you. Deliberately does *not* open the popover — the raised arm
  /// is the signal, and a window appearing over your work uninvited is how Clippy failed.
  public func awaiting(_ request: (id: String, summary: String)?) {
    self.request = request
  }

  /// A question from one of your sources. Shown in the bubble; answered in the popover.
  public func asked(_ nudge: (id: String, text: String, replyable: Bool)?) {
    self.nudge = nudge
    view.speech = nudge?.text
    if nudge != nil { speechUntil = clock + Self.speechDuration * 2 }
  }

  public func apply(_ snapshot: Snapshot?, menu: Menu = .empty) {
    inputs = CreatureInputs.from(snapshot)
    self.menu = menu
    summary = MenuBarPresentation.from(snapshot).summary
    refresh()
  }

  private func toggle() {
    guard !popover.isVisible else {
      popover.hide()
      return
    }
    // Opening the popover is the most reliable glance there is — the hub may have
    // something queued that it's been holding for exactly this moment.
    onAction("opened")

    popover.show(
      summary: summary,
      menu: menu,
      request: request,
      nudge: nudge,
      near: panel.frame,
      onChoose: { [weak self] id in self?.onAction(id) },
      onDecide: { [weak self] id, approved in
        self?.request = nil
        self?.onDecide(id, approved)
      },
      onReply: { [weak self] id, text in
        self?.nudge = nil
        self?.view.speech = nil
        self?.onReply(id, text)
      }
    )
  }

  /// The hub decided something is worth saying; the persona decides how it sounds.
  public func say(_ situation: String) {
    guard let line = persona.line(for: situation) else { return }
    view.speech = line
    speechUntil = clock + Self.speechDuration
  }

  /// Bottom-right by default. It has a home and it stays there — a creature you have to
  /// hunt for is one you stop glancing at.
  private func moveHome() {
    guard let screen = NSScreen.main else { return }
    let size = panel.frame.size
    panel.setFrameOrigin(
      NSPoint(
        x: screen.visibleFrame.maxX - size.width - 24,
        y: screen.visibleFrame.minY + 24
      )
    )
  }

  private func refresh() {
    let home = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
    let gaze = CreatureInputs.gaze(cursor: NSEvent.mouseLocation, from: home, reach: Self.gazeReach)

    var current = inputs
    current.gazeX = gaze.x
    current.gazeY = gaze.y

    // Settle toward the new pose rather than cutting to it, then lay the small motions
    // on top. States that snap are the tell that something is a sprite.
    settled = .lerp(settled, .from(current), Self.easing)
    view.pose = settled.animated(by: life.advance(to: clock))
    // Clicks land on the creature; everywhere else they pass through to your work.
    view.opaqueRegion = view.bounds.insetBy(dx: view.bounds.width * 0.12, dy: view.bounds.height * 0.12)
  }

  private func startAnimating() {
    link?.invalidate()
    let link = view.displayLink(target: self, selector: #selector(tick))
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  @objc private func tick() {
    // Asleep or hidden behind something is genuinely zero work — no frames, no gaze polling.
    guard inputs.state != 0, panel.occlusionState.contains(.visible) else { return }
    clock += 1.0 / 60
    if view.speech != nil, clock > speechUntil { view.speech = nil }
    view.breath = clock * 1.05
    refresh()
  }
}
