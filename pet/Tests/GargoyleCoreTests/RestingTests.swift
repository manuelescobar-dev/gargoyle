import CoreGraphics
import Foundation
import Testing
@testable import GargoyleCore

// "It costs nothing when it's doing nothing" is a rule that was never enforced — the
// creature breathed and blinked at 3am to an empty room.

@Test("it stays awake while you're around")
func awakeWhileYouAre() {
  #expect(Resting.shouldSleep(idleSeconds: 0, after: 300) == false)
  #expect(Resting.shouldSleep(idleSeconds: 299, after: 300) == false)
}

@Test("it drops off once you've been gone a while")
func sleepsWhenYouLeave() {
  #expect(Resting.shouldSleep(idleSeconds: 301, after: 300))
}

@Test("a state the hub is reporting keeps it up regardless")
func staysUpForSomethingThatMatters() {
  #expect(
    Resting.shouldSleep(idleSeconds: 9_999, after: 300, blocked: 1) == false,
    "an agent has been waiting for you — dozing off would be the creature lying"
  )
}

@Test("running agents don't keep it awake, though")
func runningDoesNotKeepItUp() {
  #expect(
    Resting.shouldSleep(idleSeconds: 9_999, after: 300, blocked: 0),
    "you're away and nothing needs you; there's nobody to perform for"
  )
}

// Where you put it is where it should be, on this screen and the next one.
@Test("a remembered home is used")
func remembersHome() {
  let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
  let home = CGPoint(x: 400, y: 300)
  #expect(Resting.home(remembered: home, on: screen, size: CGSize(width: 210, height: 210)) == home)
}

@Test("with nothing remembered it goes bottom-right")
func defaultHome() {
  let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
  let placed = Resting.home(remembered: nil, on: screen, size: CGSize(width: 210, height: 210))
  #expect(placed.x > screen.midX, "bottom-right, out of the way")
  #expect(placed.y < screen.midY)
}

// The case flagged in the first design pass and never handled: displays get unplugged.
@Test("a home on a screen that's gone is pulled back into view")
func clampsToVisibleScreen() {
  let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
  let size = CGSize(width: 210, height: 210)
  let offscreen = CGPoint(x: 3400, y: 2000) // the second monitor you just unplugged

  let placed = Resting.home(remembered: offscreen, on: screen, size: size)
  #expect(placed.x + size.width <= screen.maxX)
  #expect(placed.y + size.height <= screen.maxY)
  #expect(placed.x >= screen.minX && placed.y >= screen.minY)
}

@Test("a negative position is pulled back too")
func clampsNegative() {
  let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
  let placed = Resting.home(remembered: CGPoint(x: -900, y: -900), on: screen,
                            size: CGSize(width: 210, height: 210))
  #expect(placed.x >= screen.minX && placed.y >= screen.minY)
}

@Test("a screen that starts at a negative origin still works")
func handlesSecondaryScreenOrigin() {
  let secondary = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
  let placed = Resting.home(remembered: nil, on: secondary, size: CGSize(width: 210, height: 210))
  #expect(placed.x >= secondary.minX && placed.x + 210 <= secondary.maxX)
}
