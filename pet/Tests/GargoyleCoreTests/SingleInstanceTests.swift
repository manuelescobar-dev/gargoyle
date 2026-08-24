import Testing
@testable import GargoyleCore

// Two creatures on one screen is a bug you can see from across the room, and it happens
// easily: launchd has one running and you open the app, or a dev build is still up.

@Test("one running copy is fine")
func aloneIsFine() {
  #expect(SingleInstance.shouldStand(down: 1) == false)
}

@Test("a second copy stands down rather than doubling up")
func secondStandsDown() {
  #expect(SingleInstance.shouldStand(down: 2))
  #expect(SingleInstance.shouldStand(down: 5))
}

// Counting ourselves is the whole trick — zero would mean we can't see ourselves, and
// exiting then would leave you with no creature at all.
@Test("seeing nothing is not a reason to quit")
func zeroIsNotAReason() {
  #expect(SingleInstance.shouldStand(down: 0) == false)
}
