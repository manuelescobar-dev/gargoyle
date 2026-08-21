import Foundation
import Testing
@testable import GargoyleCore

@Test("a nudge arrives in the words its source chose")
func nudgeKeepsItsWords() {
  var state = HubState()
  state.received(Data(#"{"t":"bubble","id":"n1","text":"what did you eat?","replyable":true}"#.utf8))

  #expect(state.pendingNudge?.id == "n1")
  #expect(state.pendingNudge?.text == "what did you eat?")
  #expect(state.pendingNudge?.replyable == true)
}

// Someone else's question must not come out in the creature's voice.
@Test("a nudge with words bypasses the persona entirely")
func nudgeIsNotASituation() {
  var state = HubState()
  state.received(Data(#"{"t":"bubble","id":"n1","text":"stretch?","replyable":false}"#.utf8))
  #expect(state.takeSituation() == nil, "nothing here for the persona to interpret")
}

@Test("a situation with no words still goes through the persona")
func situationStillWorks() {
  var state = HubState()
  state.received(Data(#"{"t":"bubble","situation":"failed"}"#.utf8))
  #expect(state.takeSituation() == "failed")
  #expect(state.pendingNudge == nil)
}

@Test("a nudge that needs no answer isn't offered a text field")
func unreplyableNudge() {
  var state = HubState()
  state.received(Data(#"{"t":"bubble","id":"n1","text":"deploy finished","replyable":false}"#.utf8))
  #expect(state.pendingNudge?.replyable == false)
}

@Test("answering clears it")
func answeringClears() {
  var state = HubState()
  state.received(Data(#"{"t":"bubble","id":"n1","text":"stretch?","replyable":true}"#.utf8))
  state.clearNudge()
  #expect(state.pendingNudge == nil)
}

@Test("losing the hub drops the question — an answer would go nowhere")
func dropClearsNudge() {
  var state = HubState()
  state.received(Data(#"{"t":"bubble","id":"n1","text":"stretch?","replyable":true}"#.utf8))
  state.dropped()
  #expect(state.pendingNudge == nil)
}
