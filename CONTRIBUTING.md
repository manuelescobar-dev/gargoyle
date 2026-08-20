# Contributing

## Before you start

Gargoyle is deliberately small — **one creature, one attention system, one deep integration, and
everything else is a `curl`.** Most feature ideas are best answered with "that's a source" and a
three-line example, so it's worth checking
[decision 0005](decisions/0005-a-surface-not-a-suite.md) before building something we'd decline.

Open an issue first for anything beyond a fix. Design is the expensive part of this project; code is
the cheap part, and it's a shame to write the cheap part twice.

## Setup

Requires **Node 24+** (the hub runs TypeScript directly — there is no build step) and **macOS 14+**
with Xcode for the pet.

```bash
git clone https://github.com/manuelescobar-dev/gargoyle
cd gargoyle/hub
npm install
npm test          # 18 tests
npm start         # hub on 127.0.0.1:7373
```

Poke at it without an agent running:

```bash
curl -X POST localhost:7373/event -H 'content-type: application/json' \
  -d '{"hook_event_name":"Notification","session_id":"s1","cwd":"/tmp/demo"}'
curl -s localhost:7373/state
```

## The workflow

**1. Plan before you implement.** Say what you intend to change — which files, which layer, what the
tests will assert — in the issue, before writing code. A wrong shape costs a sentence to fix at this
stage and a rewrite to fix in review. If you're working with Claude Code, use plan mode.

**2. Branch.** `<type>/<short-description>` — `feat/menu-bar-item`, `fix/blocked-timestamp-reset`,
`docs/creature-contract`.

**3. Write the failing test first.** Especially for bug fixes, where it isn't optional: the test must
fail on the buggy code and pass on the fix. See [ENGINEERING.md](ENGINEERING.md#testing) for how deep
to go.

**4. Keep it green.**

```bash
cd hub && npm test && npm run check
```

**5. Open the PR.** Link the issue. Say what you decided and why — the diff already says what
changed.

## Commit messages

Say **why**, not what.

```
Label embers by worktree, not session id

A session id means nothing at a glance. The worktree is how you
actually think about which agent is which.
```

If a commit encodes a judgment call that would be expensive to revisit later, don't bury it in the
message — write it up in [`decisions/`](decisions/README.md) instead.

## What goes where

| | |
|---|---|
| work to be done | GitHub issues, grouped by milestone |
| why something is the way it is | [`decisions/`](decisions/README.md) — with what would change our mind |
| how code is structured and tested | [ENGINEERING.md](ENGINEERING.md) |
| what the project is and isn't | [docs/](docs/) — story and principles, no implementation detail |
| the hub↔pet wire format | [protocol/](protocol/README.md) |
| adding a creature | [creatures/README.md](creatures/README.md) |

## A note on scope

If a change makes the screen busier, adds a notification, or gives the creature a reason to speak
that it didn't have before, it needs an unusually good argument. Those aren't arbitrary preferences
— they're in [docs/principles.md](docs/principles.md), and they're most of what makes this thing
tolerable to keep on screen.
