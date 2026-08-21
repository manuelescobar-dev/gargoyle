# 0006 — What each Claude Code hook actually means

*2026-08-20*

## Decided

| hook | we treat it as |
|---|---|
| `PermissionRequest` | **blocked** — the precise "waiting on a human" signal |
| `Notification` (matcher `idle_prompt\|agent_needs_input`) | **blocked** — idle-waiting, which nothing else reports |
| `PermissionDenied` | active — you answered, it moves on |
| `StopFailure` | **failed** — the turn ended on an API error |
| `PostToolUseFailure` | **active** — see below |
| `Stop` | done |
| `SessionEnd` | remove from the registry |
| `SessionStart`, `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SubagentStart`, `SubagentStop` | active |

## Why this needed writing down

The first implementation mapped **all** of `Notification` to blocked. `Notification` also
fires for `auth_success` and `agent_completed`, so a successful login would have made the
creature demand your attention. The installer now narrows it with a matcher so the
irrelevant ones never arrive, and the parser doesn't map bare `Notification` at all.

## A failed tool is not a failed session

`PostToolUseFailure` is deliberately mapped to *active*. A red test suite, a grep that
finds nothing, a build that breaks — that's routine agent work, and it's usually the exact
thing the agent is about to fix. Showing a dropped, dimmed ember for it would be the
creature lying about state, which is the one thing it must never do.

`StopFailure` is different: the turn itself died — rate limit, overload, auth, billing.
That's a run that isn't coming back without you.

## What we rely on

Only the **documented common fields**: `session_id`, `cwd`, `hook_event_name`. The
per-event payload extras aren't published, so we don't depend on them. An unrecognised
hook name returns null rather than throwing, so a newer Claude Code can't take the hub down.

## What would change it

Published per-event schemas. `Stop` and `SubagentStop` carry `last_assistant_message`,
which would let a nudge say *what* finished rather than just that something did.

`PermissionRequest` presumably carries the tool and its input — that's what
[#13](https://github.com/manuelescobar-dev/gargoyle/issues/13) needs to show *"wants to
write src/auth/session.ts"* rather than just "blocked", and it's the door to approving
from the popover.

## Hooks load at session start

Claude Code reads `settings.json` hooks when a session begins, so installing them has no
effect on the session you installed from. `install` says so explicitly — without it the
first five minutes are "I installed it and nothing happened", and the natural next move is
to go looking for a bug that isn't there.
