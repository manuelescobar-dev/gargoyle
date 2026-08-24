import CoreGraphics
import Testing
@testable import GargoyleCore

private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
private let creature = CGRect(x: 1280, y: 24, width: 210, height: 210)

// It was landing somewhere different each time, which makes it feel broken even though it
// works. The cause was measuring the window before SwiftUI had laid it out.

@Test("the same popover lands in the same place every time")
func deterministic() {
  let size = CGSize(width: 260, height: 180)
  let a = PopoverPlacement.origin(for: size, near: creature, on: screen)
  let b = PopoverPlacement.origin(for: size, near: creature, on: screen)
  #expect(a == b)
}

// With room either side. Near an edge the clamp wins, which is its own test below.
@Test("it sits centred on the creature when there's room")
func centred() {
  let size = CGSize(width: 260, height: 180)
  let roomy = CGRect(x: 600, y: 24, width: 210, height: 210)
  let origin = PopoverPlacement.origin(for: size, near: roomy, on: screen)
  #expect(abs((origin.x + size.width / 2) - roomy.midX) < 0.001)
}

// Where the creature actually lives: bottom-right, close enough to the edge that centring
// would hang it off the screen.
@Test("at its usual home it's nudged left rather than hanging off the edge")
func nudgedAtHome() {
  let origin = PopoverPlacement.origin(for: CGSize(width: 260, height: 180), near: creature, on: screen)
  #expect(origin.x + 260 <= screen.maxX)
  #expect(origin.x + 260 > creature.midX, "still overlapping the creature, not shoved away")
}

// Growing taller shouldn't shift it sideways — that's the movement you actually notice.
@Test("a taller popover doesn't move sideways")
func heightDoesNotShiftX() {
  let short = PopoverPlacement.origin(for: CGSize(width: 260, height: 120), near: creature, on: screen)
  let tall = PopoverPlacement.origin(for: CGSize(width: 260, height: 420), near: creature, on: screen)
  #expect(short.x == tall.x)
}

@Test("it stays on screen at the edges")
func staysOnScreen() {
  let corner = CGRect(x: 1480, y: 8, width: 210, height: 210)
  let origin = PopoverPlacement.origin(for: CGSize(width: 260, height: 180), near: corner, on: screen)
  #expect(origin.x >= screen.minX)
  #expect(origin.x + 260 <= screen.maxX)
}

@Test("a popover taller than the screen is still anchored on screen")
func absurdlyTall() {
  let origin = PopoverPlacement.origin(for: CGSize(width: 260, height: 4000), near: creature, on: screen)
  #expect(origin.y >= screen.minY, "never pushed off the bottom trying to fit the top")
}
