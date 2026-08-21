# 0004 — OpenClaw is an optional integration

*2026-08-20*

## Decided

**Gargoyle must be fully useful with OpenClaw not installed.**

The agent-watching half — hooks, worktrees, permission prompts, terminal focus — is entirely ours
and touches OpenClaw nowhere. That's M0 through M2, and it's the part that makes Gargoyle Gargoyle.

The assistant half — memory, cron, skills, conversational nudges — is OpenClaw's and we won't
rebuild a line of it.

## Why

A focused tool for watching your agents shouldn't require a general-purpose personal assistant
framework as a hard dependency. Most people who want the first thing don't want the second.

It also de-risks the open question: if OpenClaw turns out not to expose a channel a client can
register on, we lose the assistant half's plumbing, not the product.

## Consequence for personality

The creature has a name and a real temperament either way. Without OpenClaw, mood is *mechanical* —
derived from agent load, time of day, how the last few runs went — and lines come from
persona-seeded variant pools. No model, no network, deterministic.

That's most of the aliveness. Mood plus irregularity plus animation craft is what makes something
feel real; the language model is not what does that work.

With OpenClaw it gets generated lines and a memory that buys **fewer and better** interruptions.

## Resolved

It doesn't — OpenClaw channels are in-process npm plugins, not clients that connect in.
It turned out not to matter: a channel plugin is a shim onto `/nudge` and `/reply`, which
already exist, so the integration needs no code here at all.
See [0008](0008-openclaw-needs-nothing-from-us.md).
