# 0007 — Actions that touch other apps run in the pet, not the hub

*2026-08-20*

## Decided

The hub decides **which** terminal to raise. The pet performs the raise.

## Why

macOS gates cross-app control behind Automation permission (TCC), and TCC needs a GUI
identity to attribute a prompt to. **A launchd agent has none**, so the request isn't
denied loudly — it's denied silently. `osascript` returns a non-result, nothing appears
on screen, and the button looks broken for reasons nobody can see.

The pet is a real running app. The prompt appears, it's attributed to Gargoyle, and the
user can answer it. First use is also exactly when it should be asked: a creature that
demands Automation permission at launch is a creature people delete.

## The shape this forces

Anything that reaches out of our own process — raising a window, driving another app,
reading the screen — belongs in the pet. The hub stays a headless event bus that decides
*what should happen*, and hands the surface a concrete instruction.

That happens to match the existing split rather than fighting it. The hub resolves
`focus:<sessionId>` to a terminal identity, which is semantics; the pet turns that into an
AppleScript and runs it, which is local desktop work.

## How the session is identified

Not by matching window titles, which is guesswork. The hook command runs **inside the
agent's own shell**, so it already knows which terminal tab it's in — it sends
`$TERM_SESSION_ID` and `$TERM_PROGRAM` as headers. iTerm's AppleScript `id` is the UUID
half of `ITERM_SESSION_ID`, verified identical, so we can select the exact pane.

Terminal.app exposes no stable per-tab id, so it gets raised to the app and no further.
Any other terminal is activated by name — cruder than nothing is not.

## What would change it

Shipping the hub inside a signed app bundle rather than as a bare launchd agent would give
it a TCC identity. That's a packaging change we'd want anyway for distribution, and it
would make this decision optional rather than forced. It wouldn't make it wrong.
