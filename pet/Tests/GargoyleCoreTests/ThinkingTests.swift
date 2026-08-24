import Foundation
import Testing
@testable import GargoyleCore

// A silent gap while an agent turn runs reads as broken. This is what makes a slow answer
// legible as a slow answer rather than a creature that ignored you.

@Test("the creature knows when it's working on something")
func thinkingArrives() {
  var state = HubState()
  state.received(Data(#"{"t":"thinking","on":true}"#.utf8))
  #expect(state.thinking)

  state.received(Data(#"{"t":"thinking","on":false}"#.utf8))
  #expect(state.thinking == false)
}

@Test("an answer arriving stops the thinking")
func answerEndsThinking() {
  var state = HubState()
  state.received(Data(#"{"t":"thinking","on":true}"#.utf8))
  state.received(Data(#"{"t":"bubble","id":"s1","text":"ok","replyable":false}"#.utf8))
  #expect(state.thinking == false, "the bubble is the answer; nothing is still pending")
}

// If the hub goes away mid-thought, a creature stuck thinking forever is worse than one
// that admits it doesn't know.
@Test("losing the hub stops the thinking")
func dropStopsThinking() {
  var state = HubState()
  state.received(Data(#"{"t":"thinking","on":true}"#.utf8))
  state.dropped()
  #expect(state.thinking == false)
}

@Test("thinking doesn't disturb what's true")
func thinkingDoesNotClobberState() {
  var state = HubState()
  state.received(Data(#"{"t":"state","state":"working","embers":[],"mood":0,"blocked":0}"#.utf8))
  state.received(Data(#"{"t":"thinking","on":true}"#.utf8))
  #expect(state.latest?.state == .working)
}

// The dots have to move, or it reads as a bubble that got stuck.
@Test("the waiting dots animate")
func dotsAnimate() {
  let frames = stride(from: 0.0, through: 3.0, by: 0.25).map { Thinking.dots(at: $0) }
  #expect(Set(frames).count >= 3, "a static ellipsis looks like a hang")
  #expect(frames.allSatisfy { $0.count <= 3 && $0.allSatisfy { c in c == "." } })
}
