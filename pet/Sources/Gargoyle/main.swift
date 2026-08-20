import AppKit
import GargoyleCore

// No bundle, no Info.plist, no Xcode project — `.accessory` at runtime is all a
// menu bar app needs.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = StatusItemController()

// Pushed, not polled: the hub tells us when something changes, and a closed socket
// is an unambiguous "we don't know" rather than a pause we might mistake for calm.
let connection = HubConnection { snapshot in
  controller.apply(MenuBarPresentation.from(snapshot))
}
connection.start()

app.run()
