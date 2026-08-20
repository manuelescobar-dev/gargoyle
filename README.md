# Gargoyle

A desktop creature that perches on the edge of your screen and keeps watch over your AI coding agents.

Gargoyles sit on the edge of a structure and watch over it. That's the whole product: a small creature
anchored to your screen edge that shows you, at a glance and without interrupting you, what your agents
are doing — and lets you act on them without hunting through terminal windows.

> Status: design phase. Nothing is built yet.

---

## The core idea

**Physiology, not badges.** Most desktop pets are a cute sprite with a notification dot bolted on — the
character is decoration and the badge does the work. Gargoyle inverts that: the creature's body *is* the
display. If a state can't be expressed through the creature's anatomy and behavior, it doesn't get a state.

**It tends your agents.** Each running session is a small light the creature holds — an ember.

| situation | what you see |
|---|---|
| 4 agents running | it's juggling four, absorbed, busy |
| one finishes | that ember settles and goes soft |
| **one needs you** | it stops everything and holds that ember out toward you |
| one failed | a dropped, dimmed ember on the ground beside it |
| nothing running | it pockets them and dozes |

Count, status, and urgency become readable with zero text and zero badges. Eight agents should look
genuinely overwhelming, because it is.

---

## Design principles

**Peripheral vision drives the state design.** Your peripheral vision is nearly colorblind but extremely
motion-sensitive. So `needs-you` must be a *motion* pattern that breaks the creature's silhouette — never a
red dot, which your periphery effectively cannot see. Conversely `working` must stay under a low motion
budget or it yanks your eye every few seconds. Color is for when you're already looking; motion is for when
you're not.

**Home, not wandering.** Shimeji-style pets wander and climb your windows. Delightful, and wrong here — if it
moves, you have to *find* it, and you can never build the muscle memory of throwing your cursor at a fixed
spot. Gargoyle anchors to a screen edge and stays there, draggable to a new home it remembers, with a short
**leash**: it drifts a little when you're idle and returns when you come back. Wandering is for toys,
anchoring is for tools; the leash gets you both.

**Adaptive liveliness.** Near-frozen while you're typing or an agent is mid-run. Playful when you've been
idle a few minutes. Properly asleep when you're away. A pet that's charming *at the wrong moment* is the one
that gets uninstalled.

**The interruption ladder.** Every notification passes through one policy module, and the default is low:

```
change appearance silently  →  badge/count  →  speech bubble on next glance
   →  real notification (small allowlist)  →  sound (almost never)
```

Respect macOS Focus modes. Batch anything non-urgent. The gargoyle is something you *look at*, not something
that *talks to you*.

**Deliver on the next natural glance.** A nudge becoming *eligible* and a nudge becoming *visible* are two
different events. Queue it, then surface it at a moment you're already looking — you just clicked it, an
agent just finished, you came back from lunch. That attention is free; an interruption is not.

**Craft.** Irregular timing (identical loops read as dead), real weight when dragged, blended transitions
between states, never the same variant twice.

---

## Architecture

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

The hub stays out of the pet process. You'll restart the UI constantly while tuning the creature and you
don't want to lose agent state each time. It also makes the surface replaceable — a menu-bar version, a phone
client — without touching the logic.

### Stack

| layer | choice | why |
|---|---|---|
| window | Swift `NSPanel` | `.nonactivatingPanel` + `becomesKeyOnlyIfNeeded` gives non-focus-stealing *and* text input in one window. Electron can't. |
| creature | [Rive](https://rive.app/docs/runtimes/ios-macos/ios-macos) | the state machine ships *inside* the `.riv` file. `RiveView` inherits from `NSView` on macOS. |
| hub | Node | MCP SDK, Agent SDK, file watching |
| transport | local WebSocket | push-based, trivially reconnects |

**Why Rive over sprites/Live2D/Spine:** Rive is the only option where the state machine is the artifact. The
hub sets `agentCount = 4`, `needsYou = true`, `mood = 0.3` and the art responds. Adding a creature means
authoring a `.riv` against the contract — zero code. Sprite sheets can't blend between states, which is most
of perceived animation quality, and the art volume (states x variants x creatures) kills the roster.

**Why not Electron:** ~150MB idle for something running 24/7, and nearly every feature here is a macOS system
API — Accessibility to focus the waiting agent's terminal, `NSWorkspace` for context, EventKit for calendar
gating, `SFSpeechRecognizer` for push-to-talk, ScreenCaptureKit, `SMAppService`. In Electron each is a native
module or a shell-out.

---

## The creature contract

Gargoyle is a roster, not one mascot. Creatures are swappable **manually** — the states are defined
semantically and each creature implements them with its own anatomy.

> **`needs-you`** — break your silhouette with repeated outward motion, present the ember toward the user.
> Must be detectable in peripheral vision at 48px.

- **Octopus** — an arm extends out and waves it
- **Alien** — antenna cranes forward, third eye opens
- **Crow** — hops to the edge, wings half-open, ember in beak
- **Slime** — a pseudopod extrudes and pulses

Every creature must supply:

```
states       8 semantic states, each meeting a legibility requirement
load         must visibly distinguish 1 / 2-3 / 4-6 / 7+ agents (HOW is free)
gaze         one anchor tracking the cursor — eye, sensor, or body orientation
palette      a mood ramp that's diegetic for that creature
home         how it attaches to a screen edge
silhouette   must pass the 48px squint test
```

### State vocabulary

```
asleep      you're away
idle        loose, tracks your cursor, occasionally loses interest
working     absorbed, tending embers, LOW motion budget
needs-you   breaks silhouette, presents ember — the one that must be unmissable
done        brief flourish, ember settles, decays fast
failed      droops, ember dims and drops, it looks down at it
speaking    a queued nudge surfacing
listening   attentive posture, motion stills
```

**First creature: octopus.** Arms map to agents, so load reads as posture with nothing to count. The
`needs-you` gesture is native — one arm leaves the silhouette and waves. Chromatophores make the mood palette
diegetic rather than a status light. It clings to edges, which is the anchor model. And a round mantle with
radiating arms survives 48px.

**Mood lives inside the creature, not above it.** One octopus that's groggy Monday morning, smug after a
clean run, frazzled with six agents going. Rotating the *identity* would reset the peripheral-vision language
you spent all this effort building; rotating the *mood* deepens it.

---

## Build order

Each milestone is independently useful. Ship one, live with it two weeks, then add the next.

- **M0 — no creature at all.** Hub + Claude Code hooks + an `NSStatusItem` reading "2 agents need you."
  A weekend. If you don't find yourself glancing at it, stop — you learned the expensive thing cheaply.
- **M1** — swap the menu bar for the floating gargoyle. Body state only, no interaction.
- **M2** — click → popover. Dynamic context menu: new worktree, session here, jump to waiting agent.
- **M3** — OpenClaw wiring. Gargoyle as a channel: nudges in, text back out.
- **M4** — voice, weekly review, Slack/Gmail signal.

### The killer feature

Running several sessions across worktrees, the expensive failure isn't "I didn't notice it finished" — it's
**an agent silently stalled 20 minutes ago waiting on a permission prompt.** Claude Code's `Notification`,
`Stop`, `SubagentStop`, and `PreToolUse` hooks make this cheap to detect:

```jsonc
// ~/.claude/settings.json
{
  "hooks": {
    "Notification": [{ "hooks": [{ "type": "command",
      "command": "curl -s -m 2 -X POST localhost:7373/event --data-binary @-" }] }]
    // same for Stop, SubagentStop, SessionStart
  }
}
```

Hooks get JSON on stdin including `session_id`, `cwd`, and `transcript_path` — so one curl line hands the hub
the entire event stream, and `cwd` labels each agent by worktree.

**Approve/deny from the popover** is the highest-leverage feature on the list. Two paths: *cheap* — show which
session is waiting, one click focuses that terminal (90% of the value, an afternoon). *Real* — a `PreToolUse`
hook POSTs to the hub and blocks until you click. Elegant, but it makes your agents depend on the hub being
alive. Non-negotiable timeout falling through to normal behavior.

---

## Get right early

- **One event schema** — `{source, sessionId, cwd, type, ts, payload}` for everything. New sources become a
  day each instead of bespoke work.
- **Interruption ladder as one function** — if it scatters, you can never tune the noise, and noise kills this.
- **Menu items as config, not code** — you'll rewrite that list constantly.
- **Creature state machine as data** — declared in the `.riv`, not tangled into render code.
- **Hit-test the creature, not its bounding box** — clicks on transparent pixels must pass through.
- **Run at display refresh** (ProMotion 120Hz), then drop to zero frames when idle or occluded.

## Open questions

- **Does OpenClaw expose a custom channel?** A local HTTP/WS surface a client can register on, or would this
  mean patching it? The "gargoyle as OpenClaw's face" plan rests on it. Fallback: the hub calls OpenClaw
  skills directly and skips the channel abstraction. Worth confirming on day one, not at M3.
- **Reading macOS notifications** requires Full Disk Access against the `usernoted` SQLite DB, which Apple
  keeps changing. Prefer source APIs (Slack, Gmail, Linear, Calendar) — more reliable, and better signal:
  they can tell a direct question from a channel-wide FYI.
- **Focus-mode detection** is a plist-reading hack on every stack. No clean public API.

## Prior art

The agent-pet genre exists — [clawd-on-desk](https://github.com/rullerzhou-afk/clawd-on-desk),
[openpets](https://github.com/alvinunreal/openpets), [codex-pets](https://github.com/codex-pets/codex-pets),
[Clyde](https://github.com/QingJ01/Clyde) — but every one of them is **output-only**. The pet is a status
indicator with a face; information flows agent → pet and never back. None let you click the creature and act.

The mascot lineage (Neko '89, eSheep '95, Shimeji '09, Desktop Mate) is pure presence with no command layer.
[Clippy-with-a-local-LLM](https://github.com/felixrieseberg/clippy) has input but executes nothing. Command
palettes have input and execution but no persistence — summoned by hotkey, then gone.

Gargoyle is the intersection none of them occupy.
