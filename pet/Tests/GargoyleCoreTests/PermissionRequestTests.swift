import Foundation
import Testing
@testable import GargoyleCore

private let requestFrame = Data(
  #"{"t":"request","id":"r7","summary":"Write src/auth/session.ts"}"#.utf8
)

@Test("a permission request arrives with something readable to decide on")
func requestArrives() {
  var state = HubState()
  state.received(requestFrame)

  #expect(state.pendingRequest?.id == "r7")
  #expect(state.pendingRequest?.summary == "Write src/auth/session.ts")
}

// The hub gives up after a timeout and lets the agent fall back to its terminal prompt.
// A button still sitting there would send a decision nobody is waiting for any more.
@Test("a withdrawn request disappears")
func withdrawnRequestGoes() {
  var state = HubState()
  state.received(requestFrame)
  state.received(Data(#"{"t":"withdraw","id":"r7"}"#.utf8))
  #expect(state.pendingRequest == nil)
}

@Test("withdrawing a different request leaves this one alone")
func withdrawOnlyMatching() {
  var state = HubState()
  state.received(requestFrame)
  state.received(Data(#"{"t":"withdraw","id":"other"}"#.utf8))
  #expect(state.pendingRequest?.id == "r7")
}

@Test("losing the hub clears the question")
func dropClearsRequest() {
  var state = HubState()
  state.received(requestFrame)
  state.dropped()
  #expect(state.pendingRequest == nil, "answering into a dead socket would do nothing")
}

@Test("a request doesn't disturb what's true")
func requestDoesNotClobberState() {
  var state = HubState()
  state.received(Data(#"{"t":"state","state":"needs-you","embers":[],"mood":0,"blocked":1}"#.utf8))
  state.received(requestFrame)
  #expect(state.latest?.state == .needsYou)
}

@Test("a newer request replaces an older one")
func newerRequestWins() {
  var state = HubState()
  state.received(requestFrame)
  state.received(Data(#"{"t":"request","id":"r8","summary":"Bash: rm -rf build"}"#.utf8))
  #expect(state.pendingRequest?.id == "r8")
}
