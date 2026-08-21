import Foundation

/// Diagnostics, off unless `GARGOYLE_TRACE=1`.
///
/// Exists because most of what goes wrong here is invisible: a socket that never
/// connected, a message that arrived but was dropped, an AppleScript quietly denied
/// by TCC. None of it produces an error anyone would see.
public enum Trace {
  private static let enabled = ProcessInfo.processInfo.environment["GARGOYLE_TRACE"] != nil

  public static func log(_ message: @autoclosure () -> String) {
    guard enabled else { return }
    FileHandle.standardError.write(Data("\(message())\n".utf8))
  }
}
