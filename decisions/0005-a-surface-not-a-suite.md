# 0005 — No verticals, ever

*2026-08-20*

## Decided

Gargoyle ships **one opinion**: how a thing on your screen should ask for your attention. The
creature, the embers, the ladder, the queue, the popover.

It ships no verticals. No fitness tracking, no nutrition logging, no stock widget, no habit
anything — not now, not later.

## Why

The project started as a seven-item wishlist, which was really five products. This is the principle
that prevents that, and it works by saying no to almost every feature request it will ever receive.

## How anything else gets in

**Push** — an HTTP endpoint. Anything that can make a request creates an ember or a nudge.

```bash
curl -X POST localhost:7373/event -d '{"id":"ci","status":"running","label":"build"}'
```

A bash script, a cron job, an iOS Shortcut, another app, an agent. No SDK, no plugin API, no
sandbox, no language binding.

**Pull** — declared sources in config. Run a command on a schedule or a gate, turn its output into
an ember.

The hub never learns what a stock is. It learns that a command produced something worth a glance.

## The one exception

**Claude Code.** Built in, because it needs depth a generic endpoint can't give: reading hook
payloads, mapping sessions to worktrees, answering a blocked permission prompt from the popover.

That's also honest about what this is — a tool for watching coding agents that happens to have a
good enough attention system to hang other things off.
