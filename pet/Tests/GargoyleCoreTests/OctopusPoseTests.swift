import CoreGraphics
import Testing
@testable import GargoyleCore

private func inputs(state: Int, load: Int = 0, blocked: Int = 0, mood: Double = 0)
  -> CreatureInputs
{
  CreatureInputs(state: state, load: load, blocked: blocked, mood: mood)
}

private enum S {
  static let asleep = 0, idle = 1, working = 2, needsYou = 3, unknown = 8
}

@Test("it always has eight arms, whatever the load")
func alwaysEightArms() {
  for load in [0, 1, 5, 8, 40] {
    #expect(OctopusPose.from(inputs(state: S.working, load: load)).arms.count == 8)
  }
}

@Test("one arm per agent, and it stops at eight")
func armsHoldEmbers() {
  #expect(OctopusPose.from(inputs(state: S.idle)).arms.filter(\.holdsEmber).count == 0)
  #expect(OctopusPose.from(inputs(state: S.working, load: 3)).arms.filter(\.holdsEmber).count == 3)
  #expect(
    OctopusPose.from(inputs(state: S.working, load: 40)).arms.filter(\.holdsEmber).count == 8,
    "an octopus can look overwhelmed without growing extra arms"
  )
}

// The single most important thing the creature does. Peripheral vision catches motion
// that leaves an outline; it cannot catch a colour change.
@Test("needs-you extends one arm well past the others")
func presentingArmBreaksSilhouette() {
  let pose = OctopusPose.from(inputs(state: S.needsYou, load: 4, blocked: 1))
  let presenting = pose.arms.filter(\.isPresenting)

  #expect(presenting.count == 1, "exactly one — two would read as flailing, not asking")

  let others = pose.arms.filter { !$0.isPresenting }.map(\.reach).max() ?? 0
  #expect(
    presenting[0].reach > others * 1.4,
    "it has to clearly leave the outline, not just stretch a bit"
  )
}

// It's holding a light *out to you*. An empty arm waving is a creature gesturing at
// nothing, which is the whole signal wasted.
@Test("the asking arm is always holding the ember it's asking about")
func presentingArmAlwaysHoldsAnEmber() {
  for load in 1...8 {
    let pose = OctopusPose.from(inputs(state: S.needsYou, load: load, blocked: 1))
    let presenting = pose.arms.first(where: \.isPresenting)
    #expect(presenting?.holdsEmber == true, "load \(load): nothing to present")
  }
}

@Test("nothing presents when nothing is blocked")
func nothingPresentsWhenCalm() {
  for state in [S.idle, S.working, S.asleep] {
    #expect(OctopusPose.from(inputs(state: state, load: 3)).arms.allSatisfy { !$0.isPresenting })
  }
}

@Test("several blocked agents still produce one asking arm")
func manyBlockedStillOneArm() {
  let pose = OctopusPose.from(inputs(state: S.needsYou, load: 6, blocked: 4))
  #expect(pose.arms.filter(\.isPresenting).count == 1)
}

@Test("asleep is drawn in, awake is not")
func asleepCurlsUp() {
  let sleeping = OctopusPose.from(inputs(state: S.asleep))
  let awake = OctopusPose.from(inputs(state: S.idle))
  #expect(sleeping.arms.map(\.reach).max()! < awake.arms.map(\.reach).max()!)
  #expect(sleeping.eyeOpen < 0.2, "eyes shut")
}

@Test("a busy octopus looks tense")
func moodSquashesTheMantle() {
  let calm = OctopusPose.from(inputs(state: S.working, load: 1, mood: 0))
  let frazzled = OctopusPose.from(inputs(state: S.working, load: 6, mood: 1))
  #expect(frazzled.mantleSquash > calm.mantleSquash)
}

@Test("the eye tracks the cursor and stays inside the head")
func eyeFollowsGaze() {
  var looking = inputs(state: S.idle)
  looking.gazeX = 1
  looking.gazeY = -1
  let pose = OctopusPose.from(looking)

  #expect(pose.pupil.x > 0 && pose.pupil.y < 0, "it looks where you are")
  #expect(hypot(pose.pupil.x, pose.pupil.y) <= 1.0, "and never outside its own eye")
}

// Confidently showing calm while the hub is gone is the one thing it must never do.
//
// This asserts a difference you'd see at 48px in the corner of your eye — not merely a
// difference in the numbers. An earlier version only checked the two poses weren't equal,
// which passed while the two rendered indistinguishably.
@Test("unknown is visibly different from idle, not just numerically")
func unknownIsVisiblyDifferent() {
  let unknown = OctopusPose.from(inputs(state: S.unknown))
  let idle = OctopusPose.from(inputs(state: S.idle))

  let spread = { (p: OctopusPose) -> Double in
    let angles = p.arms.map(\.baseAngle)
    return angles.max()! - angles.min()!
  }

  #expect(
    spread(unknown) < spread(idle) * 0.5,
    "the silhouette itself must change — colour and eyelids vanish at 48px"
  )
  #expect(unknown.vitality < idle.vitality * 0.5, "and it should look drained")
}

// `speaking` and `listening` sat in the vocabulary unreachable — the bubble appeared while
// the body carried on as though nothing were happening.

@Test("speaking turns toward you and holds still enough to read")
func speakingIsLegible() {
  let speaking = OctopusPose.from(inputs(state: 6, load: 2))
  let working = OctopusPose.from(inputs(state: S.working, load: 2))

  #expect(speaking != working)
  #expect(
    speaking.arms.map(\.reach).max()! < working.arms.map(\.reach).max()!,
    "arms draw in — nothing should compete with the words"
  )
  #expect(speaking.eyeOpen > 0.8, "it's looking at you")
}

@Test("listening is attentive rather than busy")
func listeningIsAttentive() {
  let listening = OctopusPose.from(inputs(state: 7, load: 3))
  #expect(listening.eyeOpen > 0.9, "wide open — it's waiting on you")
  #expect(listening.mantleSquash < 0.35, "leaning in, not tensed up")
}

@Test("speaking and listening are told apart")
func speakingIsNotListening() {
  #expect(OctopusPose.from(inputs(state: 6)) != OctopusPose.from(inputs(state: 7)))
}

@Test("holding an ember doesn't stop it speaking")
func speakingStillHoldsEmbers() {
  let pose = OctopusPose.from(inputs(state: 6, load: 4))
  #expect(pose.arms.filter(\.holdsEmber).count == 4, "the work doesn't pause because it said something")
}
