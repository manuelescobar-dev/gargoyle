import AppKit

/// Reports what the pet can see of your desktop, so the hub can rank the menu.
///
/// The pet observes and reports; it decides nothing. Which agent is worth jumping to is
/// semantics and stays in the hub — this just supplies the one fact only a desktop app
/// can know: which terminal you're actually looking at.
///
/// Event-driven rather than polled. Nothing runs while you stay in one app.
@MainActor
public final class DesktopContext {
  private let report: (String?) -> Void
  private var observer: NSObjectProtocol?
  private var lastReported: String??

  public init(report: @escaping (String?) -> Void) {
    self.report = report
  }

  public func start() {
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] note in
      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      MainActor.assumeIsolated { self?.activated(app) }
    }
    activated(NSWorkspace.shared.frontmostApplication)
  }

  private func activated(_ app: NSRunningApplication?) {
    // Only asked when you switch *into* a terminal we can query — an osascript call on
    // every app switch would be a poll wearing an event's clothes.
    let session = app?.bundleIdentifier == "com.googlecode.iterm2" ? currentITermSession() : nil

    guard lastReported != .some(session) else { return }
    lastReported = .some(session)
    report(session)
  }

  private func currentITermSession() -> String? {
    let script = """
      tell application "iTerm2"
        try
          return id of current session of current tab of current window
        on error
          return ""
        end try
      end tell
      """
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    guard (try? process.run()) != nil else { return nil }
    process.waitUntilExit()

    let id = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    Trace.log("context: iTerm session \(id.isEmpty ? "(none)" : id)")
    return id.isEmpty ? nil : id
  }

  /// Explicit rather than in `deinit` — a nonisolated deinit can't touch main-actor state,
  /// and the controller outlives the app anyway.
  public func stop() {
    guard let observer else { return }
    NSWorkspace.shared.notificationCenter.removeObserver(observer)
    self.observer = nil
  }
}
