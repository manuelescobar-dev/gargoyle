import Foundation
import Testing
@testable import GargoyleCore

private func snap(_ state: Snapshot.State, running: Int = 0, blocked: Int = 0) -> Snapshot {
  let embers =
    (0..<running).map { Snapshot.Ember(id: "r\($0)", label: "r\($0)", status: .running, since: 0) }
    + (0..<blocked).map { Snapshot.Ember(id: "b\($0)", label: "b\($0)", status: .blocked, since: 0) }
  return Snapshot(state: state, embers: embers, mood: 0.25, blocked: blocked, attention: nil)
}

// The index is a contract with every .riv file ever authored. Reordering it silently
// changes what every creature displays, so it's pinned here.
@Test("state indices match the documented vocabulary order")
func stateIndices() {
  let expected: [(Snapshot.State, Int)] = [
    (.asleep, 0), (.idle, 1), (.working, 2), (.needsYou, 3),
    (.done, 4), (.failed, 5), (.speaking, 6), (.listening, 7), (.unknown, 8),
  ]
  for (state, index) in expected {
    #expect(CreatureInputs.from(snap(state)).state == index, "\(state) must stay at \(index)")
  }
}

@Test("no snapshot means unknown, not asleep")
func nilIsUnknown() {
  #expect(CreatureInputs.from(nil).state == 8)
  #expect(CreatureInputs.from(nil).load == 0)
}

@Test("load and blocked count what the creature has to hold")
func loadAndBlocked() {
  let inputs = CreatureInputs.from(snap(.needsYou, running: 3, blocked: 2))
  #expect(inputs.load == 5, "everything it's holding")
  #expect(inputs.blocked == 2)
}

@Test("mood comes from the hub, not from the pet")
func moodPassesThrough() {
  #expect(CreatureInputs.from(snap(.working)).mood == 0.25)
}

@Test("gaze is continuous and normalised, never a canned pose")
func gazeIsContinuous() {
  let home = CGPoint(x: 100, y: 100)
  let right = CreatureInputs.gaze(cursor: CGPoint(x: 400, y: 100), from: home, reach: 300)
  #expect(right.x == 1.0)
  #expect(abs(right.y) < 0.001)

  let halfway = CreatureInputs.gaze(cursor: CGPoint(x: 250, y: 100), from: home, reach: 300)
  #expect(abs(halfway.x - 0.5) < 0.001, "halfway must be 0.5, not snapped to an extreme")
}

@Test("gaze saturates rather than pointing off into infinity")
func gazeSaturates() {
  let far = CreatureInputs.gaze(cursor: CGPoint(x: 99999, y: 99999), from: .zero, reach: 300)
  #expect(far.x <= 1.0 && far.y <= 1.0)
}

@Test("a cursor on top of the creature produces a neutral gaze")
func gazeAtRest() {
  let same = CreatureInputs.gaze(cursor: CGPoint(x: 50, y: 50), from: CGPoint(x: 50, y: 50), reach: 300)
  #expect(same.x == 0 && same.y == 0, "must not divide by zero into a NaN the renderer can't use")
}

// Whatever is configured, it has to be a creature that exists — a name that doesn't match
// would leave you with a blank panel and no clue why.
@Test("an unknown creature falls back to one that exists")
func unknownCreatureFallsBack() {
  #expect(Creatures.names.contains(Creatures.chosen()))
}

@Test("every creature that ships can actually be made")
func allCreaturesAreReal() {
  #expect(Creatures.names.count >= 3)
  #expect(Creatures.names.contains("dinosaur"))
}
