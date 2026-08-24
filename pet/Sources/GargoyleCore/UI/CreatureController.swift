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
  /// Reports something you said unprompted.
  public var onSay: (String) -> Void = { _ in }
  private let view: any CreatureRenderer
  private var inputs = CreatureInputs.from(nil)
  private var persona = PersonaLoader.load(creature: Creatures.chosen())
  private var speechUntil: Double = -1
  private var clock: Double = 0
  private var wasAsleep = false
  private var thinking = false
  private var escalation = Escalation()
  /// Set while push-to-talk is held.
  public private(set) var listening = false

  public func setListening(_ value: Bool) {
    guard listening != value else { return }
    listening = value
    refresh()
  }
  private var link: CADisplayLink?

  /// How long a line stays up. Long enough to read on a glance, short enough that it
  /// isn't still sitting there next time you look over.
  private static let speechDuration: Double = 6

  /// How far away the cursor can be and still be worth looking at.
  private static let gazeReach: Double = 600

  /// Where you last put it. A plain file rather than UserDefaults, which is keyed by
  /// bundle id and behaves differently under `swift run`.
  private static let homeFile = URL(fileURLWithPath: NSHomeDirectory())
    .appending(path: "Library/Application Support/Gargoyle/home.json")

  public init() {
    // Which creature is a name, not a code change.
    view = Creatures.make(Creatures.chosen(), frame: panel.contentLayoutRect)
    view.autoresizingMask = [.width, .height]
    panel.contentView = view
    view.onClick = { [weak self] in self?.toggle() }
    moveHome()

    // Dragging is how you move it, so that's when to remember where it went.
    NotificationCenter.default.addObserver(
      forName: NSWindow.didMoveNotification,
      object: panel,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.rememberHome()
        // Drag the creature and whatever it's showing comes with it.
        self.popover.follow(self.panel.frame)
      }
    }

    // A remembered spot can end up on a screen that no longer exists.
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in MainActor.assumeIsolated { self?.moveHome() } }
    panel.orderFront(nil)
    apply(nil)
    startAnimating()
  }

  /// A question waiting on you. Deliberately does *not* open the popover — the raised arm
  /// is the signal, and a window appearing over your work uninvited is how Clippy failed.
  public func awaiting(_ request: (id: String, summary: String)?) {
    self.request = request
  }

  /// What the creature last asked, if it's still waiting on an answer.
  public var pendingNudgeId: String? { nudge?.replyable == true ? nudge?.id : nil }

  /// Whether it's working on something you said. Shown as moving dots, because a silent
  /// gap is indistinguishable from being ignored.
  public func setThinking(_ value: Bool) {
    guard thinking != value else { return }
    thinking = value
    if !value, view.speech == Thinking.dots(at: clock) { view.speech = nil }
    refresh()
  }

  /// Clears the question once it's been answered by voice.
  public func answered() {
    nudge = nil
    view.speech = nil
  }

  /// A question from one of your sources. Shown in the bubble; answered in the popover.
  public func asked(_ nudge: (id: String, text: String, replyable: Bool)?) {
    self.nudge = nudge
    view.speech = nudge?.text
    if nudge != nil { speechUntil = clock + Self.speechDuration * 2 }
  }

  public func apply(_ snapshot: Snapshot?, menu: Menu = .empty) {
    // The ladder's top rung, and the only one that leaves the screen. The hub decides when
    // it's earned; this just makes sure it happens once.
    if escalation.shouldNotify(snapshot?.attention) {
      let waiting = snapshot?.embers.filter { $0.status == .blocked }.map(\.label) ?? []
      Notify.send(
        waiting.count == 1
          ? "\(waiting[0]) has been waiting a while."
          : "\(waiting.count) agents have been waiting a while."
      )
    }

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
      },
      onSay: { [weak self] text in self?.onSay(text) }
    )
  }

  /// The hub decided something is worth saying; the persona decides how it sounds.
  public func say(_ situation: String) {
    guard let line = persona.line(for: situation) else { return }
    view.speech = line
    speechUntil = clock + Self.speechDuration
  }

  /// Where you left it, pulled back into view if that spot is gone. It has a home and it
  /// stays there — a creature you have to hunt for is one you stop glancing at.
  private func moveHome() {
    guard let screen = NSScreen.main else { return }
    let placed = Resting.home(
      remembered: rememberedHome(),
      on: screen.visibleFrame,
      size: panel.frame.size
    )
    panel.setFrameOrigin(NSPoint(x: placed.x, y: placed.y))
  }

  private func rememberedHome() -> CGPoint? {
    guard let data = try? Data(contentsOf: Self.homeFile),
          let point = try? JSONDecoder().decode([String: Double].self, from: data),
          let x = point["x"], let y = point["y"]
    else { return nil }
    return CGPoint(x: x, y: y)
  }

  private func rememberHome() {
    let origin = panel.frame.origin
    try? FileManager.default.createDirectory(
      at: Self.homeFile.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let encoded = try? JSONEncoder().encode(["x": origin.x, "y": origin.y])
    try? encoded?.write(to: Self.homeFile)
  }

  private func refresh() {
    let home = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
    let gaze = CreatureInputs.gaze(cursor: NSEvent.mouseLocation, from: home, reach: Self.gazeReach)

    var current = inputs
    // Two states only the pet can know: the hub can't tell you walked away, and it can't
    // tell how long a bubble has been on screen. Everything else comes down the wire.
    if wasAsleep {
      current = CreatureInputs(state: 0, load: current.load, blocked: 0, mood: 0)
    } else if thinking {
      // About to speak, which is what `speaking` already looks like: drawn in and still.
      current = CreatureInputs(state: 6, load: current.load, blocked: current.blocked, mood: current.mood)
    } else if listening {
      current = CreatureInputs(state: 7, load: current.load, blocked: current.blocked, mood: current.mood)
    } else if view.speech != nil {
      current = CreatureInputs(state: 6, load: current.load, blocked: current.blocked, mood: current.mood)
    }
    current.gazeX = gaze.x
    current.gazeY = gaze.y

    // Settle toward the new pose rather than cutting to it, then lay the small motions
    // on top. States that snap are the tell that something is a sprite.
    view.show(current, breath: clock)
    // Clicks land on the creature; everywhere else they pass through to your work.
    view.updateHitRegion()
  }

  private func startAnimating() {
    link?.invalidate()
    let link = view.displayLink(target: self, selector: #selector(tick))
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  @objc private func tick() {
    // Zero work while asleep or hidden: no frames, no gaze polling, no osascript.
    guard panel.occlusionState.contains(.visible) else { return }

    let idle = Resting.idleSeconds()
    let asleep = Resting.shouldSleep(
      idleSeconds: idle,
      after: Resting.defaultIdleSeconds,
      blocked: inputs.blocked
    )
    if asleep != wasAsleep {
      wasAsleep = asleep
      Trace.log("creature \(asleep ? "asleep" : "awake") (idle \(Int(idle))s)")
      refresh()
    }
    guard !asleep else { return }
    clock += 1.0 / 60

    if thinking {
      // Kept live so the dots move; nothing else may expire the bubble meanwhile.
      view.speech = Thinking.dots(at: clock)
      speechUntil = clock + Self.speechDuration
    } else if view.speech != nil, clock > speechUntil {
      view.speech = nil
    }
    refresh()
  }
}
