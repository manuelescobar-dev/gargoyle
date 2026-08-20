# Architecture

```
┌── pet (Swift) ─────────────  pure surface. renders state, gaze, physics,
│                              hit-testing. owns zero logic.
│         ▲ websocket
├── hub (Node) ──────────────  THE PRODUCT. local event bus:
│                              ← Claude Code hooks (HTTP)
│                              ← session log watching
│                              ← Slack / Gmail / Linear / Calendar
│                              → state machine, interruption policy
│         ▲
└── openclaw ────────────────  memory, cron, skills — the assistant half
```

The hub stays out of the pet process. You'll restart the UI constantly while tuning the creature and you don't
want to lose agent state each time. It also makes the surface replaceable — a menu-bar version, a phone client
— without touching the logic.

## Stack

| layer | choice | why |
|---|---|---|
| window | Swift `NSPanel` | `.nonactivatingPanel` + `becomesKeyOnlyIfNeeded` gives non-focus-stealing *and* text input in one window. Electron can't. |
| creature | [Rive](https://rive.app/docs/runtimes/ios-macos/ios-macos) | the state machine ships *inside* the `.riv` file. `RiveView` inherits from `NSView` on macOS. |
| hub | Node | MCP SDK, Agent SDK, file watching |
| transport | local WebSocket | push-based, trivially reconnects |

### Why Rive over sprites / Live2D / Spine

Rive is the only option where the state machine is the artifact. The hub sets `agentCount = 4`,
`needsYou = true`, `mood = 0.3` and the art responds. Adding a creature means authoring a `.riv` against the
[contract](creatures.md) — zero code.

Sprite sheets can't blend between states, which is most of perceived animation quality, and the art volume
(states × variants × creatures) kills the roster.

### Why not Electron

~150MB idle for something running 24/7, and nearly every feature here is a macOS system API — Accessibility to
focus the waiting agent's terminal, `NSWorkspace` for context, EventKit for calendar gating,
`SFSpeechRecognizer` for push-to-talk, ScreenCaptureKit, `SMAppService`. In Electron each is a native module or
a shell-out.

## Get right early

- **One event schema** — `{source, sessionId, cwd, type, ts, payload}` for everything. New sources become a day
  each instead of bespoke work.
- **Interruption ladder as one function** — if it scatters, you can never tune the noise, and noise kills this.
- **Menu items as config, not code** — you'll rewrite that list constantly.
- **Creature state machine as data** — declared in the `.riv`, not tangled into render code.
- **Hit-test the creature, not its bounding box** — clicks on transparent pixels must pass through.
- **Run at display refresh** (ProMotion 120Hz), then drop to zero frames when idle or occluded.
