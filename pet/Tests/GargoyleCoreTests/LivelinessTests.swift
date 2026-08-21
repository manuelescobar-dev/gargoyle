import Testing
@testable import GargoyleCore

// Identical loops read as dead. Everything here exists to keep the creature off a
// perfect cycle, because that's what the eye notices.

@Test("blinks land at uneven intervals, never on a metronome")
func blinksAreIrregular() {
  var life = Liveliness()
  var gaps: [Double] = []
  var last = 0.0

  var t = 0.0
  while t < 200 && gaps.count < 8 {
    t += 1.0 / 60
    if life.advance(to: t).justBlinked {
      gaps.append(t - last)
      last = t
    }
  }

  #expect(gaps.count >= 5, "it should blink several times in a few minutes")
  #expect(Set(gaps.map { Int($0 * 10) }).count > 2, "a fixed cadence reads as a machine")
}

@Test("each arm sways on its own phase")
func armsSwayIndependently() {
  var life = Liveliness()
  let frame = life.advance(to: 3.2)
  let offsets = (0..<8).map { frame.sway(arm: $0) }

  #expect(Set(offsets.map { Int($0 * 1000) }).count > 5, "arms moving in lockstep look like a rake")
  #expect(offsets.allSatisfy { abs($0) < 0.2 }, "a sway, not a flail")
}

@Test("the asking arm waves rather than holding still")
func askingArmWaves() {
  var life = Liveliness()
  let samples = stride(from: 0.0, through: 2.0, by: 0.05).map {
    life.advance(to: $0).presentingWave
  }
  #expect(samples.max()! - samples.min()! > 0.2, "an extended arm that never moves reads as stuck")
}

@Test("it settles into a new pose instead of snapping to it")
func posesAreEased() {
  let calm = OctopusPose.from(CreatureInputs(state: 1, load: 0, blocked: 0, mood: 0))
  let busy = OctopusPose.from(CreatureInputs(state: 3, load: 5, blocked: 1, mood: 0.8))

  let quarter = OctopusPose.lerp(calm, busy, 0.25)
  #expect(quarter.mantleSquash > calm.mantleSquash)
  #expect(quarter.mantleSquash < busy.mantleSquash, "a cut between states is the tell of a sprite")

  #expect(OctopusPose.lerp(calm, busy, 0) == calm)
  #expect(OctopusPose.lerp(calm, busy, 1) == busy)
}

// Whether an arm is *holding* something can't be half-true, even mid-transition.
@Test("easing never invents a half-held ember")
func discreteFactsDontInterpolate() {
  let empty = OctopusPose.from(CreatureInputs(state: 1, load: 0, blocked: 0, mood: 0))
  let holding = OctopusPose.from(CreatureInputs(state: 3, load: 4, blocked: 1, mood: 0))
  let mid = OctopusPose.lerp(empty, holding, 0.5)

  #expect(mid.arms.filter(\.holdsEmber).count == holding.arms.filter(\.holdsEmber).count)
  #expect(mid.arms.filter(\.isPresenting).count == 1)
}
