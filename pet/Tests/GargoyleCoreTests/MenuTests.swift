import Foundation
import Testing
@testable import GargoyleCore

@Test("a menu decodes from the wire")
func decodesMenu() throws {
  let json = #"{"t":"menu","items":[{"id":"focus:s3","label":"Jump to billing-fix"}]}"#
  let menu = try JSONDecoder().decode(Menu.self, from: Data(json.utf8))
  #expect(menu.items.first?.id == "focus:s3")
  #expect(menu.items.first?.label == "Jump to billing-fix")
}

// The pet must not decide what's actionable — that's the hub's job, and it's what keeps
// a second surface cheap to build.
@Test("the pet shows what it's given, in the order it's given")
func preservesHubOrdering() throws {
  let json = """
    {"t":"menu","items":[
      {"id":"a","label":"First"},{"id":"b","label":"Second"},{"id":"c","label":"Third"}]}
    """
  let menu = try JSONDecoder().decode(Menu.self, from: Data(json.utf8))
  #expect(menu.items.map(\.label) == ["First", "Second", "Third"])
}

@Test("an empty menu is valid — sometimes there's nothing to do")
func emptyMenuIsFine() throws {
  let menu = try JSONDecoder().decode(Menu.self, from: Data(#"{"t":"menu","items":[]}"#.utf8))
  #expect(menu.items.isEmpty)
}

@Test("an item with an unknown extra field still decodes")
func forwardCompatibleItems() throws {
  let json = #"{"t":"menu","items":[{"id":"a","label":"A","icon":"star","weight":3}]}"#
  let menu = try JSONDecoder().decode(Menu.self, from: Data(json.utf8))
  #expect(menu.items.count == 1, "a newer hub must not blank the menu")
}

@Test("a menu message is heard without disturbing the state")
func menuDoesNotClobberState() {
  var state = HubState()
  state.received(Data(#"{"t":"state","state":"needs-you","embers":[],"mood":0,"blocked":1}"#.utf8))
  state.received(Data(#"{"t":"menu","items":[{"id":"x","label":"Do the thing"}]}"#.utf8))

  #expect(state.menu.items.map(\.id) == ["x"])
  #expect(state.latest?.state == .needsYou, "the menu must not overwrite what's true")
}

@Test("losing the hub empties the menu — stale actions are worse than none")
func dropClearsMenu() {
  var state = HubState()
  state.received(Data(#"{"t":"menu","items":[{"id":"x","label":"Do the thing"}]}"#.utf8))
  state.dropped()
  #expect(state.menu.items.isEmpty, "offering an action we can no longer perform is a lie")
}
