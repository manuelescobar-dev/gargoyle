import CoreGraphics
import Testing
@testable import GargoyleCore

private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

@Test("a window filling the screen means don't interrupt")
func fullscreenIsUndisturbed() {
  #expect(Undisturbed.covers(window: screen, screen: screen))
}

@Test("a window a hair short of the edges still counts")
func nearlyFullscreenCounts() {
  let almost = CGRect(x: 0, y: 0, width: 1511, height: 981)
  #expect(Undisturbed.covers(window: almost, screen: screen), "rounding shouldn't decide this")
}

@Test("an ordinary window doesn't")
func normalWindowIsFine() {
  #expect(Undisturbed.covers(window: CGRect(x: 100, y: 100, width: 900, height: 700), screen: screen) == false)
}

// A maximised window is not the same as presenting. The menu bar being visible is the
// difference between "working with a big window" and "don't put anything on my screen".
@Test("a maximised window that leaves the menu bar alone doesn't count")
func maximisedIsNotFullscreen() {
  let maximised = CGRect(x: 0, y: 38, width: 1512, height: 944)
  #expect(Undisturbed.covers(window: maximised, screen: screen) == false)
}

@Test("nothing on screen isn't a reason to go quiet")
func noWindowIsNotUndisturbed() {
  #expect(Undisturbed.covers(window: nil, screen: screen) == false)
}

@Test("a zero-sized screen can't be covered")
func degenerateScreen() {
  #expect(Undisturbed.covers(window: .zero, screen: .zero) == false)
}
