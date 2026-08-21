import Testing
@testable import GargoyleCore

@Test("the UUID is pulled out of iTerm's session id")
func extractsUUID() {
  #expect(
    TerminalFocus.sessionUUID("w12t0p0:5AC6470C-6004-4A0A-B9C6-423A2840736B")
      == "5AC6470C-6004-4A0A-B9C6-423A2840736B"
  )
  #expect(TerminalFocus.sessionUUID("5AC6470C") == "5AC6470C")
}

@Test("iTerm gets a script that selects the exact tab")
func iTermScriptSelectsTab() throws {
  let script = try #require(TerminalFocus.script(app: "iTerm.app", term: "w12t0p0:ABC-123"))
  #expect(script.contains("iTerm2"))
  #expect(script.contains("ABC-123"))
  #expect(script.contains("select"), "activating the app alone leaves you on whatever was frontmost")
}

@Test("Terminal.app is raised even though we can't pick the tab")
func terminalAppFallsBack() throws {
  let script = try #require(TerminalFocus.script(app: "Apple_Terminal", term: "x:Y"))
  #expect(script.contains("Terminal"))
  #expect(!script.contains("iTerm"))
}

@Test("an unrecognised terminal is still worth raising")
func unknownTerminalActivates() throws {
  let script = try #require(TerminalFocus.script(app: "Ghostty", term: ""))
  #expect(script.contains("Ghostty"))
  #expect(script.contains("activate"))
}

@Test("nothing to go on means no script, rather than a guess")
func nothingToGoOn() {
  #expect(TerminalFocus.script(app: nil, term: nil) == nil)
  #expect(TerminalFocus.script(app: "", term: "") == nil)
  #expect(TerminalFocus.script(app: "iTerm.app", term: "") == nil, "iTerm needs a session to find")
}

// These strings arrive over a socket from a shell environment we don't control. The text
// surviving as data is fine; escaping the string literal and becoming a statement is not.
@Test("quotes can't break out of the string literal")
func quotesCannotEscape() throws {
  let script = try #require(
    TerminalFocus.script(app: "iTerm.app", term: #"w0t0p0:A"; do shell script "rm -rf ~"#)
  )
  #expect(!script.contains(#"A"; do"#), "an unescaped quote would end the literal here")
  #expect(script.contains(#"A\"; do"#), "escaped and inert, not dropped")
}

@Test("backslashes are escaped too")
func backslashesEscaped() throws {
  let script = try #require(TerminalFocus.script(app: "iTerm.app", term: #"w0t0p0:A\"#))
  #expect(script.contains(#"A\\"#), "a trailing backslash would otherwise escape our closing quote")
}
