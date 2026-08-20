# Open questions

## Does OpenClaw expose a custom channel?

A local HTTP/WS surface a client can register on, or would this mean patching it? The "gargoyle as OpenClaw's
face" plan rests on it. Fallback: the hub calls OpenClaw skills directly and skips the channel abstraction.

Worth confirming on day one, not at [M3](roadmap.md).

## Reading macOS notifications

Requires Full Disk Access against the `usernoted` SQLite DB, which Apple keeps changing. Prefer source APIs
(Slack, Gmail, Linear, Calendar) — more reliable, and better signal: they can tell a direct question from a
channel-wide FYI.

## Focus-mode detection

A plist-reading hack on every stack. No clean public API.
