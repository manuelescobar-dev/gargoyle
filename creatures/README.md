# Creatures

A creature is two files.

```
creatures/octopus/
  octopus.riv     the body   — animation and state machine
  persona.md      the voice  — name, temperament, how it speaks
```

Gargoyle is a roster. Creatures are swapped by hand, never automatically — your eye learns a creature's
silhouette without you noticing, and rotating it on a timer would throw that away every morning.

Adding one is authoring, not coding. If you have to touch Swift to add a creature, the contract has failed.

---

## The rule that governs everything

**States are defined by what they must *achieve*, not by what pose to strike.** Each creature satisfies them
with its own anatomy.

> **`needs-you`** — break your silhouette with repeated outward motion and present the ember toward the user.
> Must be detectable in peripheral vision at 48px.

- **Octopus** — an arm extends past the body and waves it
- **Crow** — hops to the edge, wings half-open, ember in beak
- **Alien** — antenna cranes forward, third eye opens
- **Slime** — a pseudopod extrudes and pulses

Four anatomies, one meaning. That shared meaning is the language your eye learns, and it's the one thing a new
creature must not break.

## The nine states

| state | what it means | must achieve |
|---|---|---|
| `asleep` | you're away | almost no motion, clearly not watching |
| `idle` | nothing running | loose, tracks your cursor, sometimes loses interest |
| `working` | agents running | absorbed. **low motion budget** — this must not pull your eye |
| `needs-you` | something is blocked | **breaks silhouette with repeated motion.** the unmissable one |
| `done` | a run finished | brief flourish, decays fast |
| `failed` | a run failed | downward, inward, dimmed |
| `speaking` | a queued nudge surfacing | oriented toward you, holding still enough to read |
| `listening` | push-to-talk is open | attentive posture, motion stills |
| `unknown` | **the hub is gone** | visibly not-knowing. never a confident idle |

`unknown` is not optional. A status display that is confidently wrong is worse than none, because you stop
checking the real thing. When the socket drops, the creature enters this state on its own — it doesn't wait to
be told, because the thing that would tell it is what disappeared.

## What the `.riv` must expose

The hub sets these; the state machine inside the file decides what they look like.
The pet builds them in `CreatureInputs` (`pet/Sources/GargoyleCore/Domain/CreatureInputs.swift`),
and the state indices are pinned by a test — **appending to the vocabulary is safe,
reordering it silently changes what every creature displays.**

| input | type | range | meaning |
|---|---|---|---|
| `state` | number | 0–8 | index into the nine states above, **in that order** |
| `load` | number | 0–8+ | how many embers it's holding |
| `blocked` | number | 0–8+ | how many of them need you |
| `mood` | number | 0–1 | drives the palette. calm → frazzled |
| `gazeX` `gazeY` | number | −1–1 | direction of the cursor, continuous |
| `edge` | number | 0–3 | which screen edge it's clinging to |
| `poke` | trigger | — | it was clicked or dragged |

Gaze is **continuous**, never a set of canned look-left / look-right poses. Discrete gaze is the tell that
something is a sprite rather than a creature.

## What else a creature must satisfy

**Load must be legible.** 1, 2–3, 4–6, and 7+ have to look meaningfully different. *How* is free — limbs,
orbiting, a nest, a hoard, being visibly buried. Nobody should ever have to count.

**One gaze anchor.** An eye, a sensor, a whole-body orientation. Something that clearly points at your cursor.

**A diegetic palette.** Mood should read as the creature doing what it does — an octopus changing color, a
lantern dimming — not a status light glued to its side.

**A way to cling.** It anchors to a screen edge and stays there.

**The 48px squint test.** Shrink it, blur it, look away. If you can't tell `working` from `needs-you`, redraw
it. This is the only test that actually matters, because it's the size and attention you'll really give it.

## The persona file

Same file serves two fidelities. Without OpenClaw the sample lines seed variant pools — no model, no network,
deterministic. With OpenClaw it becomes the system prompt and lines are generated in character.

Personality is **voice, not volume**. It shapes how something already worth saying gets said. It never creates
a reason to speak.

```markdown
---
name: Tako
temperament: [dry, unbothered, quietly competent]
speaks: sparingly
---

## Voice
Two sentences on how it talks, and what it would never say.

## Moods
| when | it becomes |
|---|---|
| six agents running | frazzled |
| a clean run | smug |

## Lines
### needs-you
- "this one's been waiting."
```

Every situation needs **at least three lines**. The creature must never say the same thing twice in a row —
repetition is the fastest way to make something feel dead.

See [octopus/persona.md](octopus/persona.md) for a complete one.
