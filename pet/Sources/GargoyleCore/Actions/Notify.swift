import UserNotifications

/// A real notification, for the one case the creature's own body has plainly failed to
/// carry: something has been waiting on you for a long time and you haven't looked.
///
/// Permission is asked for the first time that happens, not at launch. A creature that
/// wants to send you notifications the moment it appears is a creature people delete.
public enum Notify {
  public static func send(_ body: String) {
    let centre = UNUserNotificationCenter.current()

    centre.requestAuthorization(options: [.alert]) { granted, error in
      guard granted else {
        Trace.log("notify: not allowed\(error.map { " — \($0)" } ?? "")")
        return
      }

      let content = UNMutableNotificationContent()
      content.title = "Still waiting"
      content.body = body

      centre.add(
        UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
      ) { error in
        if let error { Trace.log("notify: \(error)") }
      }
    }
  }
}
