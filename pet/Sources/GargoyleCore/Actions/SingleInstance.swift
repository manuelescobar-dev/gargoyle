import AppKit

/// Stops two creatures ending up on one screen.
///
/// Easy to do by accident: launchd has one running and you open the app from Finder, or a
/// dev build is still up from earlier. The result is visible from across the room and
/// looks like a bug in the creature rather than two copies of it.
public enum SingleInstance {
  /// Pure so the rule is arguable in a test. Zero means we can't see ourselves, which is
  /// never a reason to quit — that would leave you with no creature at all.
  public static func shouldStand(down running: Int) -> Bool {
    running > 1
  }

  /// True if another copy is already on screen and this one should bow out.
  public static func alreadyRunning() -> Bool {
    guard let id = Bundle.main.bundleIdentifier else {
      // A dev build with no bundle can't be counted, so it never stands down. Running
      // `swift run` alongside the installed app is a thing you'd be doing deliberately.
      return false
    }
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: id).count
    if SingleInstance.shouldStand(down: running) {
      Trace.log("another creature is already on screen — standing down")
      return true
    }
    return false
  }
}
