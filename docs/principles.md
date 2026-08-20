# Principles

What Gargoyle is, and what it will never become.

**Values** don't change — they're the reason the project exists and the test every decision answers to.
**Rules** are how the values show up in the product. Those can change as we learn.

---

## Values

### Physiology, not badges

Most desktop pets are a sprite with a notification dot bolted on — the character is decoration and the badge
does the work. Gargoyle inverts it: **the creature's body is the display.** If a state can't be expressed
through anatomy and behavior, it doesn't get a state.

Each running session is a light the creature holds — an ember. Count, status, and urgency, with zero text and
zero badges. Eight agents should look genuinely overwhelming, because it is.

### Built for peripheral vision

Your periphery is nearly colorblind but extremely motion-sensitive. So `needs-you` is a motion pattern that
breaks the silhouette, never a red dot — a red dot is something your periphery effectively cannot see. And
`working` stays under a low motion budget, or it yanks your eye every few seconds.

> Color is for when you're already looking. Motion is for when you're not.

### Charm must be load-bearing

Every delightful thing also does work. The octopus's arms are charming *and* they encode agent count. The
ember is cute *and* it's the status. A flourish that carries no information is clutter wearing a costume.

This is the referee between fun and clean. The bar isn't "is it fun" — it's "is it fun **and** does it tell me
something." That's what lets us keep saying yes to good ideas without the thing slowly turning into noise.

### It never wants anything from you

No streaks. No XP. No levels, leaderboards, or daily goals. No "you haven't fed me in three days." No
engagement metrics, ever.

The genre is already full of the alternative — pets that gamify your work and guilt you into checking them.
That's a slot machine with a face. Gargoyle is fun to *look at*, never fun to *grind*. It has no ambitions for
your attention beyond telling you the truth when you glance at it.

### Calm

This is the low-stress corner of the screen. There's enough going on everywhere else.

Calm is a constraint with consequences: fewer things on screen, slower motion, softer color, silence by
default, nothing blinking. If a change makes the screen busier, it needs an unusually good reason.

### Taste

Minimal, modern, finished. The mascot, the code, the README, the icon, the release notes — all of it held to
the same bar.

Taste here is restraint more than decoration: knowing what to leave out, getting the spacing right, picking
one good color instead of five. Nothing ships half-designed. If a piece isn't good yet, it waits.

### A surface, not a suite

Gargoyle ships one opinion: **how a thing on your screen should ask for your attention.** The creature, the
embers, the ladder, the queue, the popover. That's the product.

It ships no verticals. No food tracking, no stock widget, no habit anything. Anything that can produce a line
of JSON becomes a source — a shell script, a cron job, a Shortcut, another app. The hub never learns what a
stock is; it learns that a command produced something worth a glance.

The one exception is Claude Code, built in because it needs depth a generic endpoint can't give: reading hook
payloads, mapping sessions to worktrees, answering a blocked permission prompt.

This is the principle that says no to almost every feature request. That's its job.

### Boring code, interesting creature

All the surprise lives in the personality. None of it lives in the architecture.

Reading the code should feel calm; watching the creature should feel alive. Plain functions, obvious names, no
clever indirection, no framework where a file would do. Anti-cleverness in the implementation is exactly what
buys the room to be playful in the character.

---

## Rules

Derived from the values above. These can change; the values can't.

### Earn every interruption

Presence is a cost paid continuously, so silence is the default and every escalation justifies itself.

```
change appearance silently  →  badge/count  →  speech bubble on next glance
   →  real notification (small allowlist)  →  sound (almost never)
```

Respect macOS Focus modes. Batch anything non-urgent. Gargoyle is something you *look at*, not something that
*talks to you*.

### Deliver on the next natural glance

A nudge becoming *eligible* and a nudge becoming *visible* are two different events. Queue it, then surface it
when you're already looking — you just clicked the creature, an agent just finished, you came back from lunch.

That attention is free. An interruption is not.

### Never lie about state

If the hub disconnects, the creature shows that it **doesn't know**. It never keeps displaying a confident,
stale "all clear."

A status display that is confidently wrong is worse than no status display, because you stop checking the real
thing. `unknown` is a first-class state, and every creature has to be able to show it.

### It costs nothing when it's doing nothing

Zero frames when idle or occluded. No polling loops. Invisible in Activity Monitor, absent from the battery
report.

An always-on thing that shows up in either gets uninstalled no matter how good it looks.

### Never in the way

Clicks pass through transparent pixels. It never takes focus. It never covers what you're working on. One
gesture hides it completely.

Your work is the priority. The creature is a guest on your screen.

### Home, not wandering

Shimeji-style pets wander and climb your windows. Delightful, and wrong here — if it moves, you have to *find*
it, and you never build the muscle memory of throwing your cursor at a fixed spot.

Gargoyle anchors to a screen edge and stays, draggable to a new home it remembers, with a short **leash**: it
drifts a little when you're idle and returns when you're back. Wandering is for toys, anchoring is for tools;
the leash gets you both.

### Adaptive liveliness

Near-frozen while you're typing or an agent is mid-run. Playful when you've been idle a few minutes. Properly
asleep when you're away.

A pet that's charming *at the wrong moment* is the one that gets uninstalled.

### The creature changes, the language never does

Anyone can add a creature. Nobody redefines what a state means.

The roster only works because `needs-you` means the same thing on every creature. That shared meaning is the
language your eye learns without noticing, and it's the one thing a new creature must not break.

### Personality is voice, not volume

The creature has a name, a temperament, and moods that hold across a day. None of it ever creates a reason to
speak.

Personality shapes *how* something already worth saying gets said — the same permission prompt, in its voice,
with an opinion about this being the third time. It never adds a message that wouldn't otherwise exist.

The line is who started it. Charm when you've opened the popover and there's nothing to report is free; you're
already there. Charm that interrupts you is Clippy, and Clippy is the reason this project has a manner at all.

### Craft

Irregular timing, because identical loops read as dead. Real weight when dragged. Blended transitions, never
cuts. Never the same variant twice.
