import CoreGraphics
import Testing
@testable import GargoyleCore

private func inputs(state: Int, load: Int = 0, blocked: Int = 0, mood: Double = 0) -> CreatureInputs {
  CreatureInputs(state: state, load: load, blocked: blocked, mood: mood)
}

// The slime exists to test whether the contract is a contract. It has no limbs, so
// one-arm-per-agent — the octopus's whole mechanic — is unavailable to it. If the states
// still hold, they're semantic. If they don't, they were just how the octopus works.

@Test("load is legible without a single limb")
func loadWithoutLimbs() {
  let quiet = SlimePose.from(inputs(state: 1))
  let busy = SlimePose.from(inputs(state: 2, load: 6))

  #expect(busy.motes.count == 6, "embers suspended inside it, not held")
  #expect(quiet.motes.isEmpty)
  #expect(busy.size > quiet.size, "more to carry, more of it")
}

@Test("it can't grow past what it can show")
func loadSaturates() {
  #expect(SlimePose.from(inputs(state: 2, load: 40)).motes.count <= 8)
}

// The requirement is "break your silhouette with repeated outward motion" — not "extend an
// arm". A creature with no arms has to satisfy it some other way.
@Test("needs-you leaves the outline, arms or no arms")
func reachesWithoutArms() {
  let asking = SlimePose.from(inputs(state: 3, load: 3, blocked: 1))
  #expect(asking.reach > 0.5, "a pseudopod, since there's nothing else to extend")
  #expect(SlimePose.from(inputs(state: 2, load: 3)).reach == 0)
}

@Test("unknown doesn't look like idle here either")
func unknownIsDistinct() {
  let unknown = SlimePose.from(inputs(state: 8))
  let idle = SlimePose.from(inputs(state: 1))
  #expect(unknown.vitality < idle.vitality * 0.5)
  #expect(unknown.flatness > idle.flatness, "it slumps rather than fading quietly")
}

@Test("asleep puddles")
func asleepPuddles() {
  #expect(SlimePose.from(inputs(state: 0)).flatness > SlimePose.from(inputs(state: 1)).flatness)
}

@Test("speaking holds still")
func speakingIsStill() {
  #expect(SlimePose.from(inputs(state: 6)).wobble < SlimePose.from(inputs(state: 2, load: 3)).wobble)
}

@Test("it looks where you are")
func gazeFollows() {
  var looking = inputs(state: 1)
  looking.gazeX = 1
  #expect(SlimePose.from(looking).pupil.x > 0)
}
