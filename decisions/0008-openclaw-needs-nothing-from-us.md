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
