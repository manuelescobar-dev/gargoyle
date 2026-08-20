import Foundation
import Testing
@testable import GargoyleCore

private let workingFrame = Data(#"{"t":"state","state":"working","embers":[],"mood":0,"blocked":0}"#.utf8)
private let blockedFrame = Data(#"{"t":"state","state":"needs-you","embers":[],"mood":0.5,"blocked":1}"#.utf8)

@Test("a snapshot on the wire becomes the current state")
func receivesSnapshot() {
  var state = HubState()
  let changed = state.received(workingFrame)
  #expect(changed)
  #expect(state.latest?.state == .working)
}

// The whole point of #10. The hub disappearing is the one thing the pet must work
// out for itself, because whatever would have told it is what went away.
@Test("a dropped socket means unknown immediately, not stale truth")
func dropIsImmediate() {
  var state = HubState()
  state.received(blockedFrame)
  #expect(state.latest != nil)

  state.dropped()
  #expect(state.latest == nil, "showing the last known state would be the creature lying")
}

@Test("an unknown pet shows unreachable, never quiet")
func dropPresentsAsUnreachable() {
  var state = HubState()
  state.received(workingFrame)
  state.dropped()

  let presentation = MenuBarPresentation.from(state.latest)
  #expect(presentation.summary == "hub unreachable")
  #expect(presentation != MenuBarPresentation.from(
    Snapshot(state: .idle, embers: [], mood: 0, blocked: 0)
  ))
}

// A live connection that sends one bad frame is not a dead hub. The last snapshot
// was true a moment ago and nothing says otherwise.
@Test("a malformed frame is ignored, not treated as a disconnect")
func malformedFrameIsIgnored() {
  var state = HubState()
  state.received(blockedFrame)

  let changed = state.received(Data("<nonsense>".utf8))
  #expect(changed == false, "nothing changed")
  #expect(state.latest?.state == .needsYou, "the connection is still alive")
}

@Test("an identical snapshot reports no change, so nothing repaints")
func idempotentUpdates() {
  var state = HubState()
  let first = state.received(workingFrame)
  let second = state.received(workingFrame)
  #expect(first)
  #expect(second == false)
}

@Test("reconnecting after a drop restores real state")
func reconnects() {
  var state = HubState()
  state.dropped()
  #expect(state.latest == nil)

  let changed = state.received(blockedFrame)
  #expect(changed)
  #expect(state.latest?.blocked == 1)
}
