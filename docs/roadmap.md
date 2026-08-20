# Roadmap

Each milestone is independently useful. Ship one, live with it two weeks, then add the next.

| | milestone | scope |
|---|---|---|
| **M0** | **no creature at all** | Hub + Claude Code hooks + an `NSStatusItem` reading "2 agents need you." A weekend. If you don't find yourself glancing at it, stop — you learned the expensive thing cheaply. |
| **M1** | the gargoyle | Swap the menu bar for the floating creature. Body state only, no interaction. |
| **M2** | popover | Click → popover. Dynamic context menu: new worktree, session here, jump to waiting agent. |
| **M3** | OpenClaw wiring | Gargoyle as a channel: nudges in, text back out. |
| **M4** | the rest | Voice, weekly review, Slack/Gmail signal. |

## The killer feature

Running several sessions across worktrees, the expensive failure isn't "I didn't notice it finished" — it's
**an agent silently stalled 20 minutes ago waiting on a permission prompt.**

Claude Code's `Notification`, `Stop`, `SubagentStop`, and `PreToolUse` hooks make this cheap to detect:

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

### Approve/deny from the popover

The highest-leverage feature on the list. Two paths:

- **Cheap** — show which session is waiting, one click focuses that terminal. 90% of the value, an afternoon.
- **Real** — a `PreToolUse` hook POSTs to the hub and blocks until you click. Elegant, but it makes your agents
  depend on the hub being alive. Non-negotiable timeout falling through to normal behavior.
