import AppKit
import GargoyleCore

// The bundle sets LSUIElement, which does this properly. Kept for `swift run`, where
// there's no bundle to read it from.
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
  },
  // The hub decided which terminal; raising it has to happen here, because only a real
  // app can be granted Automation permission.
  onFocus: { app, term in TerminalFocus.raise(app: app, term: term) },
  onRequest: { request in creature.awaiting(request) },
  onNudge: { nudge in creature.asked(nudge) }
)

// Your answer goes wherever the source said it should. Gargoyle stores nothing itself.
creature.onReply = { id, text in
  Task {
    let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    await post("/reply", #"{"id":"\#(id)","text":"\#(escaped)"}"#)
  }
}

// Actions go straight back to the hub — the pet doesn't know what "focus:s3" means,
// and that's deliberate.
creature.onAction = { id in
  Task { await post("/action", #"{"id":"\#(id)"}"#) }
}

// Approving from the popover answers a hook that is holding the tool call open.
// Reports which terminal you're looking at, so the hub can rank the menu. Event-driven:
// nothing runs while you stay in one app.
let desktop = DesktopContext { session, undisturbed in
  let id = session.map { "\"\($0)\"" } ?? "null"
  Task { await post("/context", #"{"currentSession":\#(id),"undisturbed":\#(undisturbed)}"#) }
}
desktop.start()

// Hold ⌥Space and say it. Answers whatever the creature last asked; if it hasn't asked
// anything, what you said just isn't for us.
let talk = PushToTalk(
  onStart: { creature.setListening(true) },
  onFinish: { said in
    creature.setListening(false)
    guard let said else { return }

    // Nothing waiting means you started the conversation, rather than answering one.
    guard let pending = creature.pendingNudgeId else {
      creature.onSay(said)
      return
    }
    let escaped = said.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    Task { await post("/reply", #"{"id":"\#(pending)","text":"\#(escaped)"}"#) }
    creature.answered()
  }
)
talk.start()

// Saying something unprompted. It answers once and never follows up.
creature.onSay = { text in
  Task {
    let answer = await postForAnswer("/say", ["text": text])
    if let answer { await MainActor.run { creature.heard(answer) } }
  }
}

creature.onDecide = { id, approved in
  Task { await post("/decision", #"{"id":"\#(id)","decision":"\#(approved ? "allow" : "deny")"}"#) }
}
connection.start()

/// Posts and returns what came back, for the one call that has an answer.
func postForAnswer(_ path: String, _ body: [String: String]) async -> String? {
  guard let url = URL(string: "http://127.0.0.1:7373\(path)"),
        let payload = try? JSONSerialization.data(withJSONObject: body)
  else { return nil }

  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.httpBody = payload
  request.timeoutInterval = 90  // an agent turn is slower than a button press

  guard let (data, _) = try? await URLSession.shared.data(for: request),
        let reply = try? JSONDecoder().decode([String: String].self, from: data)
  else { return nil }

  Trace.log("say -> \(reply["text"] ?? "(nothing)")")
  return reply["text"]
}

func post(_ path: String, _ body: String) async {
  guard let url = URL(string: "http://127.0.0.1:7373\(path)") else { return }
  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.httpBody = Data(body.utf8)
  _ = try? await URLSession.shared.data(for: request)
  Trace.log("post \(path) \(body)")
}

app.run()
