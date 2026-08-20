# The creature contract

Gargoyle is a roster, not one mascot. Creatures are swappable **manually** — the states are defined
semantically and each creature implements them with its own anatomy.

> **`needs-you`** — break your silhouette with repeated outward motion, present the ember toward the user.
> Must be detectable in peripheral vision at 48px.

- **Octopus** — an arm extends out and waves it
- **Alien** — antenna cranes forward, third eye opens
- **Crow** — hops to the edge, wings half-open, ember in beak
- **Slime** — a pseudopod extrudes and pulses

Every creature must supply:

| | |
|---|---|
| `states` | 8 semantic states, each meeting a legibility requirement |
| `load` | must visibly distinguish 1 / 2–3 / 4–6 / 7+ agents (HOW is free) |
| `gaze` | one anchor tracking the cursor — eye, sensor, or body orientation |
| `palette` | a mood ramp that's diegetic for that creature |
| `home` | how it attaches to a screen edge |
| `silhouette` | must pass the 48px squint test |

## State vocabulary

| state | meaning |
|---|---|
| `asleep` | you're away |
| `idle` | loose, tracks your cursor, occasionally loses interest |
| `working` | absorbed, tending embers, LOW motion budget |
| `needs-you` | breaks silhouette, presents ember — the one that must be unmissable |
| `done` | brief flourish, ember settles, decays fast |
| `failed` | droops, ember dims and drops, it looks down at it |
| `speaking` | a queued nudge surfacing |
| `listening` | attentive posture, motion stills |

## First creature: octopus

Arms map to agents, so load reads as posture with nothing to count. The `needs-you` gesture is native — one arm
leaves the silhouette and waves. Chromatophores make the mood palette diegetic rather than a status light. It
clings to edges, which is the anchor model. And a round mantle with radiating arms survives 48px.

## Mood lives inside the creature, not above it

One octopus that's groggy Monday morning, smug after a clean run, frazzled with six agents going. Rotating the
*identity* would reset the peripheral-vision language you spent all this effort building; rotating the *mood*
deepens it.
