# hub

The part that decides things. See [../CLAUDE.md](../CLAUDE.md) for the rules and
[../ENGINEERING.md](../ENGINEERING.md) for how it's structured.

## Declared sources

Optional. Most people won't have any, and a hub with none costs nothing — the scheduler
never starts.

`~/.gargoyle/config.json`:

```json
{
  "sources": [
    { "run": "~/bin/check-ci", "every": "5m" },
    { "run": "~/bin/lunch", "every": "2h", "whenBusy": false }
  ]
}
```

Each command prints one JSON object per line — the same shapes anything can POST:

```
{"id":"ci","label":"nightly build","status":"running"}
{"text":"stand up?","reply_to":"~/bin/log-break"}
```

Anything else on stdout is ignored, so ordinary logging is harmless.

**`every`** is `30s`, `5m`, or `2h`, with a ten-second floor — below that a source is a
busy-loop wearing a schedule.

**Gating matters more than scheduling.** Nothing new starts while an agent is waiting on
you, because that attention is already spoken for. A source that genuinely can't wait sets
`"whenBusy": true`. A source still running never starts a second copy of itself, and one
that hangs is cut off rather than wedging the schedule behind it.
