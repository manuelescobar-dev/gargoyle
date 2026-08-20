import AppKit
import GargoyleCore

// No bundle, no Info.plist, no Xcode project — `.accessory` at runtime is all a
// menu bar app needs. Verified: NSStatusItem works fine from a plain executable.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = StatusItemController()
let hub = HubClient()

/// M0 polls. Issue #8 replaces this with the push socket.
let poll = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
  Task { @MainActor in
    controller.apply(MenuBarPresentation.from(await hub.fetch()))
  }
}
poll.fire()  // read once immediately rather than showing nothing for two seconds

app.run()
