import Testing
@testable import GargoyleCore

private func ember(_ label: String, _ status: Snapshot.Status) -> Snapshot.Ember {
  Snapshot.Ember(id: label, label: label, status: status)
}

private func snap(_ state: Snapshot.State, _ embers: [Snapshot.Ember]) -> Snapshot {
  Snapshot(
    state: state,
    embers: embers,
    mood: Double(embers.count) / 6.0,
    blocked: embers.filter { $0.status == .blocked }.count
  )
}

@Test("an unreachable hub is visibly different from a quiet one")
func unknownNeverLooksLikeIdle() {
  let unreachable = MenuBarPresentation.from(nil)
  let quiet = MenuBarPresentation.from(snap(.idle, []))

  #expect(unreachable != quiet)
  #expect(unreachable.symbol != quiet.symbol, "the glyph itself must differ, not just the menu text")
  #expect(unreachable.summary.localizedCaseInsensitiveContains("unreachable"))
}

@Test("blocked outranks any number of running")
func blockedWins() {
  let p = MenuBarPresentation.from(
    snap(.needsYou, [ember("a", .running), ember("b", .running), ember("c", .blocked)])
  )
  #expect(p.text == "1", "the number shown is what needs you, not the total")
  #expect(p.summary == "1 agent needs you")
}

@Test("the count pluralises")
func pluralises() {
  let p = MenuBarPresentation.from(snap(.needsYou, [ember("a", .blocked), ember("b", .blocked)]))
  #expect(p.text == "2")
  #expect(p.summary == "2 agents need you")
}

@Test("working shows how many are running")
func working() {
  let p = MenuBarPresentation.from(snap(.working, [ember("a", .running), ember("b", .running)]))
  #expect(p.text == "2")
  #expect(p.summary == "2 running")
}

@Test("a quiet machine shows no number at all")
func idleIsSilent() {
  let p = MenuBarPresentation.from(snap(.idle, []))
  #expect(p.text.isEmpty, "a zero would be noise — nothing running means nothing to say")
  #expect(p.rows.isEmpty)
}

@Test("rows name the worktree and its status")
func rowsReadable() {
  let p = MenuBarPresentation.from(snap(.needsYou, [ember("billing-fix", .blocked)]))
  #expect(p.rows == ["billing-fix · blocked"])
}

@Test("a large fleet doesn't break the count")
func largeFleet() {
  let many = (0..<12).map { ember("w\($0)", .running) }
  #expect(MenuBarPresentation.from(snap(.working, many)).text == "12")
}
