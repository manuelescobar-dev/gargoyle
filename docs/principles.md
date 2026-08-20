# Design principles

## Physiology, not badges

Most desktop pets are a cute sprite with a notification dot bolted on — the character is decoration and the
badge does the work. Gargoyle inverts that: **the creature's body is the display.** If a state can't be
expressed through the creature's anatomy and behavior, it doesn't get a state.

Each running session is a small light the creature holds — an ember. Count, status, and urgency become
readable with zero text and zero badges. Eight agents should look genuinely overwhelming, because it is.

## Peripheral vision drives the state design

Your peripheral vision is nearly colorblind but extremely motion-sensitive. So `needs-you` must be a *motion*
pattern that breaks the creature's silhouette — never a red dot, which your periphery effectively cannot see.
Conversely `working` must stay under a low motion budget or it yanks your eye every few seconds.

> Color is for when you're already looking. Motion is for when you're not.

## Home, not wandering

Shimeji-style pets wander and climb your windows. Delightful, and wrong here — if it moves, you have to *find*
it, and you can never build the muscle memory of throwing your cursor at a fixed spot.

Gargoyle anchors to a screen edge and stays there, draggable to a new home it remembers, with a short
**leash**: it drifts a little when you're idle and returns when you come back. Wandering is for toys,
anchoring is for tools; the leash gets you both.

## Adaptive liveliness

Near-frozen while you're typing or an agent is mid-run. Playful when you've been idle a few minutes. Properly
asleep when you're away. A pet that's charming *at the wrong moment* is the one that gets uninstalled.

## The interruption ladder

Every notification passes through one policy module, and the default is low:

```
change appearance silently  →  badge/count  →  speech bubble on next glance
   →  real notification (small allowlist)  →  sound (almost never)
```

Respect macOS Focus modes. Batch anything non-urgent. The gargoyle is something you *look at*, not something
that *talks to you*.

## Deliver on the next natural glance

A nudge becoming *eligible* and a nudge becoming *visible* are two different events. Queue it, then surface it
at a moment you're already looking — you just clicked it, an agent just finished, you came back from lunch.
That attention is free; an interruption is not.

## Craft

Irregular timing (identical loops read as dead), real weight when dragged, blended transitions between states,
never the same variant twice.
