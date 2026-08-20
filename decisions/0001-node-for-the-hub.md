# 0001 — Node, not Python, for the hub

*2026-08-20*

## Decided

The hub is Node 24 + TypeScript, run directly with no build step.

## Why

**Concurrency model.** The hub holds a WebSocket, runs an HTTP endpoint, watches session logs and
polls a few APIs — all at once, all day, for years. Node has one way to do that and every library
agrees on it. Python makes you pick between asyncio, threads, and blocking libraries, and the
ecosystem is split down that seam, so you end up bridging models inside your own daemon.

**Dependency count.** Node's standard library covers the HTTP server and file watching. `ws` is the
only addition. In Python this would be aiohttp or FastAPI + uvicorn, plus watchdog.

**OpenClaw is TypeScript.** The hub's job includes being OpenClaw's desktop face. Same runtime means
writing against its actual types rather than reverse-engineering a wire format across a language
boundary.

## What we did *not* decide it on

Anthropic's Python Agent SDK and MCP SDK are genuinely first-class. That was cited as a reason
early and it shouldn't have been — the gap is much narrower than it sounds.

## What would change it

Manuel preferring to write Python day to day. A hub you enjoy opening beats one that's marginally
better on paper, and this is a daemon you'll poke at for years. `uv` has fixed most of what used to
make Python daemons annoying to deploy.

This is the most expensive decision in the stack to reverse, because the hub *is* the product.
