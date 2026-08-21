# 0008 — The OpenClaw integration needs no code in Gargoyle

*2026-08-20* · closes the open question from [0004](0004-openclaw-is-optional.md)

## What we found

OpenClaw channels are **npm packages loaded in-process by the gateway**, not clients that
connect to it. A channel implements `ChannelPlugin` through `defineChannelPluginEntry`
from `openclaw/plugin-sdk/core`, and owns:

- `config.resolveAccount` / `listAccountIds` / `inspectAccount`
- `setup.applyAccountConfig`
- **`outbound.sendText(params)`** → returns `{ messageId }`
- `security.dm` and `pairing.text`

Inbound is the plugin's own business: it registers a handler, verifies whatever it needs
to, and calls the inbound dispatcher. Plugins can register HTTP routes and gateway RPC
methods via `api.registerHttpRoute` and `api.registerGatewayMethod`.

So there is **no local surface an outside client registers on**. That was the question, and
the literal answer is no.

## Why that turns out not to matter

A channel plugin is a shim, and the two ends it needs already exist:

```
OpenClaw  outbound.sendText  →  POST localhost:7373/nudge   (with reply_to)
OpenClaw  inbound dispatch   ←  the reply Gargoyle delivers
```

Gargoyle's push door takes anything that can make an HTTP request, and `/nudge` already
carries `reply_to`. **An OpenClaw channel is just another source.** Nothing in the hub
changes, nothing in the protocol changes, and no code lands in this repo.

That's [0005](0005-a-surface-not-a-suite.md) paying for itself: we built one general door
instead of an OpenClaw integration, and the integration turned out to be a user of the door.

## Decided

**No work in Gargoyle.** If someone wants this, it's a small `openclaw-plugin-gargoyle`
package living in its own repo, depending on `openclaw/plugin-sdk` — a dependency Gargoyle
never takes on, which keeps the one-dependency rule intact.

[0004](0004-openclaw-is-optional.md) stands unchanged and is now cheap to honour: Gargoyle
is fully useful without OpenClaw because it never learned OpenClaw exists.

## What would change it

Nothing about OpenClaw. If we ever wanted the *reverse* — Gargoyle driving OpenClaw rather
than surfacing for it — that's a different design, and it would be the hub calling skills
directly rather than pretending to be a channel.

---

## Revised 2026-08-21 — it needs no plugin either

The above assumed a channel plugin would be written, just not here. Two things changed that.

**The documented API isn't in the shipping version.** OpenClaw 2026.1.30's `plugin-sdk`
exports 171 names and not one of them starts with `define`; `openclaw/plugin-sdk/core`
doesn't resolve at all. `defineChannelPluginEntry` describes a version that isn't the one
installed, so writing against the docs would mean writing against something that isn't there.

**And a plugin turns out to be unnecessary.** The CLI already closes both halves:

```bash
# OpenClaw asks, through a skill or a cron job
curl -s -X POST localhost:7373/nudge \
  -d '{"text":"what did you eat?","reply_to":"openclaw agent -m \"$(cat)\""}'
```

Outbound is a `curl`. Inbound is `reply_to` — which runs a command with your answer on
stdin — pointed at `openclaw agent -m`. The answer goes back as a real agent turn.

That's the entire integration, and it's **configuration rather than code**. No plugin, no
package, no dependency, nothing in either repo.

## Why this keeps happening

Twice now the OpenClaw integration has turned out to need less than expected, and both
times for the same reason: [0005](0005-a-surface-not-a-suite.md). We built one general door
instead of an integration, so the integration keeps arriving as an ordinary user of the door.

The lesson isn't about OpenClaw. It's that a general mechanism is worth more than the
specific feature it was avoided for — and you find that out later, not when you build it.

## Verified end to end

Run against a real OpenClaw 2026.1.30 install. The nudge queued and stayed silent, surfaced
on a glance, the answer ran `reply_to`, `openclaw` was found on PATH, and the agent turn
reached its lane. It stopped there only because that install has no Anthropic credentials
configured — which is that OpenClaw's setup, not this seam.

Two things the run corrected:

**`openclaw agent` needs a session.** Bare `-m` fails with *"Pass --to, --session-id, or
--agent to choose a session"*. The example uses `--session-id gargoyle`, which also keeps
these turns in their own thread instead of interleaving with your real conversations.

**The hub needed your PATH.** launchd hands an agent a minimal PATH with no nvm, no
Homebrew and no `~/bin`, so `openclaw` — and every declared source, and every other
`reply_to` — died with "command not found". `install` now captures your PATH into the plist.
That bug would have broken essentially every integration anyone wrote, and it only surfaced
because we ran the thing rather than reasoning about it.
