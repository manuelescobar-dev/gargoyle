import Foundation

/// Raises the terminal a session is running in.
///
/// This lives in the pet rather than the hub for a specific reason: macOS won't grant
/// Automation rights to a launchd agent. There's no GUI identity to attribute the prompt
/// to, so the request is denied silently. The pet is a real app, so the prompt appears,
/// it's attributed to Gargoyle, and the user can answer it.
///
/// The hub still decides *which* terminal. This only carries out the raise.
public enum TerminalFocus {
  /// `w12t0p0:UUID` → `UUID`. iTerm's AppleScript `id` is the UUID half.
  public static func sessionUUID(_ term: String) -> String {
    guard let colon = term.lastIndex(of: ":") else { return term }
    return String(term[term.index(after: colon)...])
  }

  /// AppleScript string literals escape backslash and double quote, and nothing else.
  private static func quoted(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }

  public static func script(app: String?, term: String?) -> String? {
    guard let app, !app.isEmpty else { return nil }

    if app == "iTerm.app" {
      let uuid = quoted(sessionUUID(term ?? ""))
      guard !uuid.isEmpty else { return nil }
      // Walks to the exact pane. `select` at each level is what raises the tab —
      // activating the app alone leaves you on whatever was frontmost.
      return """
        tell application "iTerm2"
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                if id of s is "\(uuid)" then
                  select w
                  select t
                  select s
                  activate
                  return "ok"
                end if
              end repeat
            end repeat
          end repeat
        end tell
        return "not found"
        """
    }

    if app == "Apple_Terminal" {
      // Terminal.app exposes no stable per-tab id, so this raises the app and stops
      // rather than guessing at a tab.
      return "tell application \"Terminal\" to activate\nreturn \"ok\""
    }

    return "tell application \"\(quoted(app))\" to activate\nreturn \"ok\""
  }

  /// The first call triggers the Automation prompt — which is exactly when it should be
  /// asked for. A creature that demands permissions at launch gets deleted.
  @discardableResult
  public static func raise(app: String?, term: String?) -> Bool {
    guard let source = script(app: app, term: term) else {
      FileHandle.standardError.write(
        Data("focus: nothing to raise for app=\(app ?? "nil") term=\(term ?? "nil")\n".utf8)
      )
      return false
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", source]
    let pipe = Pipe()
    process.standardOutput = pipe

    let errors = Pipe()
    process.standardError = errors

    do { try process.run() } catch {
      FileHandle.standardError.write(Data("focus: couldn't run osascript — \(error)\n".utf8))
      return false
    }
    process.waitUntilExit()

    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    Trace.log("focus \(app ?? "?") -> \(output.isEmpty ? "(nothing)" : output)")
    let problem = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if output != "ok" {
      // Never fail silently. The usual cause is a declined Automation prompt, and a
      // button that quietly does nothing is worse than one that says why.
      FileHandle.standardError.write(
        Data("focus: \(output.isEmpty ? "no result" : output)\(problem.isEmpty ? "" : " — \(problem)")\n".utf8)
      )
    }
    return output == "ok"
  }
}
