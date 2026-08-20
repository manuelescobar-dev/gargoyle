# 0003 — The hub sends snapshots, never diffs

*2026-08-20*

## Decided

Every state message on the wire is the complete visual state. The pet renders exactly what it
receives and stores nothing.

## Why

It's slightly wasteful and completely worth it. If the pet only ever receives the full picture,
it has **nowhere to accumulate logic** — no reducers, no merge rules, no local state to drift out
of sync with the hub.

"The pet owns zero logic" stops being an intention and becomes structurally impossible to violate.
The protocol enforces the architecture instead of the architecture relying on discipline.

It also makes a second surface — menu bar, phone, whatever — a hundred lines rather than a rewrite.

## The one exception

`unknown` is the pet's own. When the socket drops it enters that state immediately, by itself,
without waiting to be told — because the thing that would tell it is what disappeared.

That's the single piece of logic the pet is allowed to own, and it exists so *never lie about state*
is structural rather than aspirational.

## Cost

Payloads are a few hundred bytes over localhost. Not a real cost.
