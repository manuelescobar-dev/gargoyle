import Testing
@testable import GargoyleCore

// The ladder's top rung. It existed on the wire and did nothing, which is the same failure
// as documenting a field nobody sends — just later in the chain.

@Test("nothing below notify escalates")
func quietLevelsStayQuiet() {
  var escalation = Escalation()
  for level in [Snapshot.Attention.silent, .badge, .bubble] {
    let fired = escalation.shouldNotify(level)
    #expect(fired == false, "\(level) is not a notification")
  }
}

@Test("notify escalates once")
func notifiesOnce() {
  var escalation = Escalation()
  let first = escalation.shouldNotify(.notify)
  let second = escalation.shouldNotify(.notify)
  #expect(first)
  #expect(second == false, "the same escalation must not repeat")
}

// Coming back down and going up again is a *new* thing being ignored, not the old one.
@Test("a fresh escalation notifies again")
func rearms() {
  var escalation = Escalation()
  let first = escalation.shouldNotify(.notify)
  let calmed = escalation.shouldNotify(.badge)
  let again = escalation.shouldNotify(.notify)

  #expect(first)
  #expect(calmed == false)
  #expect(again, "you answered one and started ignoring another")
}

@Test("an absent level is treated as silence")
func missingLevelIsSilent() {
  var escalation = Escalation()
  let fired = escalation.shouldNotify(nil)
  #expect(fired == false)
}
