import CoreGraphics
import Testing
@testable import GargoyleCore

private func inputs(state: Int, load: Int = 0, blocked: Int = 0, mood: Double = 0) -> CreatureInputs {
  CreatureInputs(state: state, load: load, blocked: blocked, mood: mood)
}

// The third creature, and the first with limbs that don't scale. The octopus never has to
// think about load exceeding its anatomy and the slime sidesteps anatomy entirely; a
// dinosaur has four legs, two useless arms and one tail, so load has to go somewhere else.

@Test("agents show as plates along the back")
func platesAreLoad() {
  #expect(DinosaurPose.from(inputs(state: 1)).plates.isEmpty)
  #expect(DinosaurPose.from(inputs(state: 2, load: 3)).plates.count == 3)
}

@Test("it doesn't grow a longer spine to fit more")
func platesCap() {
  #expect(DinosaurPose.from(inputs(state: 2, load: 40)).plates.count <= 8)
}

@Test("a full back looks fuller than a sparse one")
func loadIsLegible() {
  let few = DinosaurPose.from(inputs(state: 2, load: 2))
  let many = DinosaurPose.from(inputs(state: 2, load: 7))
  #expect(many.plates.count > few.plates.count)
  #expect(many.plates.allSatisfy { $0 > 0 }, "every plate has to be visible to be counted")
}

// The requirement is "break your silhouette with repeated outward motion". A dinosaur has
// no spare arm, so the tail does it — and a raised tail changes the outline completely.
@Test("needs-you rears the tail up out of the outline")
func tailBreaksSilhouette() {
  let asking = DinosaurPose.from(inputs(state: 3, load: 4, blocked: 1))
  let working = DinosaurPose.from(inputs(state: 2, load: 4))

  #expect(asking.tailLift > working.tailLift * 2, "clearly up, not slightly raised")
  #expect(asking.presenting, "and it's holding the ember out")
}

@Test("nothing is presented when nothing is blocked")
func nothingPresentedWhenCalm() {
  for state in [0, 1, 2, 4, 6, 7] {
    #expect(DinosaurPose.from(inputs(state: state, load: 3)).presenting == false)
  }
}

@Test("several blocked agents still make one gesture")
func oneGestureHoweverManyBlocked() {
  let pose = DinosaurPose.from(inputs(state: 3, load: 6, blocked: 4))
  #expect(pose.presenting)
}

// Confidently showing calm while the hub is gone is the one thing it must never do — and
// this is the assertion that once caught two states rendering identically.
@Test("unknown is visibly different from idle, not just numerically")
func dinoUnknownIsVisiblyDifferent() {
  let unknown = DinosaurPose.from(inputs(state: 8))
  let idle = DinosaurPose.from(inputs(state: 1))

  #expect(unknown.vitality < idle.vitality * 0.5, "drained")
  #expect(unknown.headDrop > idle.headDrop * 2, "and slumped — colour alone vanishes at 48px")
}

@Test("asleep is lower than anything awake")
func asleepIsLowest() {
  let asleep = DinosaurPose.from(inputs(state: 0))
  for waking in [1, 2, 3, 6, 7] {
    #expect(asleep.headDrop > DinosaurPose.from(inputs(state: waking, load: 2)).headDrop)
  }
  #expect(asleep.eyeOpen < 0.2)
}

@Test("speaking and listening hold still and look at you")
func attendingIsStill() {
  for state in [6, 7] {
    let pose = DinosaurPose.from(inputs(state: state, load: 2))
    #expect(pose.sway < DinosaurPose.from(inputs(state: 1)).sway, "nothing competes with the words")
    #expect(pose.eyeOpen > 0.8)
  }
}

@Test("failed droops rather than dimming quietly")
func failedDroops() {
  let failed = DinosaurPose.from(inputs(state: 5, load: 2))
  #expect(failed.headDrop > DinosaurPose.from(inputs(state: 2, load: 2)).headDrop)
}

@Test("it looks where you are, continuously")
func dinoGazeFollows() {
  var looking = inputs(state: 1)
  looking.gazeX = 1
  #expect(DinosaurPose.from(looking).pupil.x > 0)

  looking.gazeX = 0.5
  let half = DinosaurPose.from(looking).pupil.x
  #expect(half > 0 && half < 1, "halfway, not snapped to an extreme")
}
