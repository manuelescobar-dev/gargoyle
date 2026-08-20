import AppKit
import GargoyleCore

// No bundle, no Info.plist, no Xcode project — `.accessory` at runtime is all this needs.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let creature = CreatureController()
// The menu bar carries the menu until the popover exists (M2). The creature carries
// the state, which is the part that matters.
let statusItem = StatusItemController()

// Pushed, not polled: a closed socket is an unambiguous "we don't know", where a missed
// poll is just a pause you might mistake for calm.
let connection = HubConnection { snapshot in
  creature.apply(snapshot)
  statusItem.apply(MenuBarPresentation.from(snapshot))
}
connection.start()

app.run()
