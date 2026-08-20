import AppKit
import Testing
@testable import GargoyleCore

// These are the flags the whole idea rests on. A creature that steals focus, or that
// vanishes when you switch Space, isn't a creature you'd keep on screen — and every
// one of these is a single word someone could change without noticing.
@MainActor
@Test("the panel never takes focus away from your work")
func neverStealsFocus() {
  let panel = CreaturePanel()
  #expect(panel.styleMask.contains(.nonactivatingPanel))
  #expect(panel.becomesKeyOnlyIfNeeded, "keys only when a control genuinely needs them")
  #expect(panel.canBecomeMain == false)
}

@MainActor
@Test("it follows you across Spaces and over fullscreen apps")
func followsYouEverywhere() {
  let behavior = CreaturePanel().collectionBehavior
  #expect(behavior.contains(.canJoinAllSpaces))
  #expect(behavior.contains(.fullScreenAuxiliary), "must survive a fullscreen editor")
  #expect(behavior.contains(.stationary))
}

@MainActor
@Test("it floats above normal windows without a frame or a shadow")
func floatsCleanly() {
  let panel = CreaturePanel()
  #expect(panel.level == .floating)
  #expect(panel.isOpaque == false)
  #expect(panel.hasShadow == false, "a shadow would draw a box around a creature that has no box")
  #expect(panel.backgroundColor == .clear)
  #expect(panel.styleMask.contains(.borderless))
}

@MainActor
@Test("clicks land on the creature and pass through everywhere else")
func clickThroughOnEmptySpace() {
  let view = CreatureView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
  view.opaqueRegion = NSRect(x: 40, y: 40, width: 20, height: 20)

  #expect(view.hitTest(NSPoint(x: 50, y: 50)) === view, "on the body: ours")
  #expect(
    view.hitTest(NSPoint(x: 5, y: 5)) == nil,
    "on empty pixels: nothing — an invisible rectangle eating clicks breaks the illusion"
  )
}
