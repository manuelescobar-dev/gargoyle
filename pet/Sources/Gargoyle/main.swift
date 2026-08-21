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
var latest: Snapshot?
var latestMenu = Menu.empty

let connection = HubConnection(
  onChange: { snapshot in
    latest = snapshot
    creature.apply(snapshot, menu: latestMenu)
    statusItem.apply(MenuBarPresentation.from(snapshot))
  },
  onSay: { situation in creature.say(situation) },
  onMenu: { menu in
    latestMenu = menu
    creature.apply(latest, menu: menu)
  }
)

// Actions go straight back to the hub — the pet doesn't know what "focus:s3" means,
// and that's deliberate.
creature.onAction = { id in
  Task { await postAction(id) }
}
connection.start()

func postAction(_ id: String) async {
  guard let url = URL(string: "http://127.0.0.1:7373/action") else { return }
  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.httpBody = Data(#"{"id":"\#(id)"}"#.utf8)
  _ = try? await URLSession.shared.data(for: request)
}

app.run()
