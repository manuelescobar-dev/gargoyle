# The seam

JSON over a WebSocket at `ws://127.0.0.1:7373/socket`. The same port serves `POST /event`
for sources and `GET /health` for `doctor`. Types are hand-written on both sides against this file.

No codegen. For roughly ten message types across two languages, a schema pipeline is more machinery
than the thing it protects — see [0005](../decisions/0005-a-surface-not-a-suite.md) for why we apply
that rule to ourselves too.

**The hub sends complete snapshots, never diffs.** That's [decision 0003](../decisions/0003-snapshots-not-diffs.md),
and it's what makes the pet structurally unable to accumulate logic.

---

## Hub → Pet

### `state` — the entire visual state

Sent on connect, then only when something actually changes. An idle machine produces no
traffic at all. The pet renders this and keeps nothing.

```jsonc
{
  "t": "state",
  "state": "needs-you",     // one of the nine, see creatures/README.md
  "embers": [
    { "id": "s1", "label": "api-refactor", "status": "running", "since": 1699999 },
    { "id": "s3", "label": "billing-fix",  "status": "blocked", "since": 1699412 }
  ],
  "mood": 0.5,              // 0 calm → 1 frazzled. drives the palette
  // `since` is absolute, not a duration — a duration would change every second and put
  // a frame on the wire each time, for a creature that hasn't moved.
  "blocked": 1,
  "attention": "silent"     // silent | badge | bubble — the interruption ladder, on the wire
}
```

### `menu` — recomputed by the hub, never assembled by the pet

```jsonc
{ "t": "menu", "items": [ { "id": "focus:s3", "label": "Jump to billing-fix" } ] }
```

### `request` — a tool call is waiting on you

```jsonc
{ "t": "request", "id": "r7", "summary": "Write src/auth/session.ts" }
{ "t": "withdraw", "id": "r7" }   // answered, or nobody answered in time
```

While this is outstanding a Claude Code hook is **holding the tool call open**. The hub gives
up after 20 seconds and the agent falls back to its normal terminal prompt, so a question
left unanswered costs nothing.

### `focus` — raise a terminal

```jsonc
{ "t": "focus", "app": "iTerm.app", "term": "w12t0p0:UUID" }
```

The hub decides which; only the pet can perform it, because macOS won't grant Automation
rights to a launchd agent — [decisions/0007](../decisions/0007-who-can-ask-for-permission.md).

### `bubble` — a queued nudge, released on a natural glance

```jsonc
{ "t": "bubble", "text": "this one's been waiting.", "ttl": 30 }
```

## Pet → Hub

```jsonc
{ "t": "hello",    "creature": "octopus", "version": "0.1.0" }
{ "t": "clicked" }                                  // popover opened
{ "t": "action",   "id": "focus:s3" }               // menu item chosen
{ "t": "decision", "id": "r7", "approve": true }    // request answered
{ "t": "text",     "body": "chicken and rice" }     // freeform input
{ "t": "moved",    "x": 1840, "y": 620 }            // dragged to a new home
```

---

## The three rules this encodes

**The pet observes, the hub decides.** `/context` reports which terminal is frontmost —
a fact only a desktop app can know. What that *means* for the menu stays in the hub, which
is the only side that knows which agent runs in which terminal.

**The pet never interprets.** It receives `state: "needs-you"`, never *"billing-fix is blocked."*
All semantics live in the hub. This is what makes a second surface a hundred lines instead of a
rewrite.

**Embers are opaque.** The pet doesn't know what an agent is. It knows there are four things and one
of them is blocked. That's the whole vocabulary it needs — which is why a cron job, an unread
message, and a coding agent can all be embers without the pet learning anything new.

**`unknown` is the pet's own.** If the socket drops, the pet enters `unknown` immediately and by
itself. It does not wait to be told, because the thing that would tell it is gone. It then
reconnects with backoff, and a single malformed frame on a *live* socket is ignored rather than
treated as a disconnect — the last snapshot was true a moment ago and nothing says otherwise.

## The pet's HTTP calls

The pet answers over HTTP rather than the socket, because these are requests with a result:

```
POST /action     {"id": "focus:s3"}
POST /decision   {"id": "r7", "decision": "allow" | "deny"}
POST /context    {"currentSession": "<terminal id>" | null}
```

## Not on the wire yet

`asleep` requires user-idle detection and `listening` requires push-to-talk. Both are in the
vocabulary and neither is reachable yet — deliberately, since a state the hub can't honestly
produce shouldn't be faked.

`failed` is now reachable, from Claude Code's `StopFailure` hook — see
[decisions/0006](../decisions/0006-hook-mapping.md).
