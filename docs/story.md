# The Story

## I. Thirty-five years of creatures

In 1989 someone wrote a program called *xneko*. It put a cat on your screen. The cat chased your cursor, and
when you stopped moving, it sat down, scratched itself, and eventually fell asleep. It did nothing. It had no
purpose. It was not productive software and never pretended to be.

People loved it, and they kept rebuilding it. A sheep in 1995. A whole zoo through the nineties. The idea
survived because it answered something a menu bar can't: it made the machine feel **inhabited**.

Then in 1997 Microsoft tried to make it useful.

Clippy is remembered as a joke, which obscures what it actually was. Microsoft Agent was a real platform —
characters with animation sets, speech balloons, text-to-speech, a scripting interface. A mascot with a
command backend, twenty-five years before anyone tried it again. The technology worked.

It failed on manner. Clippy interrupted. It appeared uninvited, in the middle of your sentence, with a
suggestion you didn't ask for, and the only way to make it stop was to kill it. An entire generation learned
that a creature on your screen is something you eventually turn off.

The lineage split there, and stayed split.

**One branch kept the charm and abandoned the purpose.** Shimeji arrived in 2009 and perfected it — sprite
sheets, a behavior file, mascots that climb the edges of your windows, dangle off your browser, throw your
windows around, and quietly multiply when you're not looking. Fifteen years later Desktop Mate put a 3D
character on your desktop, shipped on Steam with a workshop full of models, and was a genuine hit. Millions of
people, in the year 2025, voluntarily installing something whose entire function is company.

**The other branch kept the purpose and abandoned the presence.** Command palettes — Quicksilver, Alfred,
Raycast. Enormously capable, summoned by a hotkey, gone the instant you're done. Nobody has ever felt
affection for a command palette. That isn't a flaw; it's the design. It doesn't want to be seen.

And then, in the last couple of years, developers rediscovered the mascot.

A small genre appeared almost at once — pixel creatures that watch your AI coding agent and react to it.
[clawd-on-desk](https://github.com/rullerzhou-afk/clawd-on-desk),
[codex-pets](https://github.com/codex-pets/codex-pets),
[Clyde](https://github.com/QingJ01/Clyde),
[agentpet](https://github.com/ntd4996/agentpet),
[openpets](https://github.com/alvinunreal/openpets). They emote when your agent thinks. They celebrate when it
finishes. Some of them level up as you code.

It's a good instinct, and it arrived for a real reason: people now run several agents at once and have no idea
what any of them are doing.

## II. The thing nobody built

Every one of those pets is **output-only**.

Information flows one direction — agent to creature — and stops. The pet is a progress bar with a face. You
can watch it all day and never once act through it. When it tells you something needs you, you still get up
and go find the terminal yourself.

Clippy could take input but couldn't execute anything. Raycast executes anything but won't stay on screen.
Shimeji stays on screen forever and can't do a thing.

Nobody occupies the middle: **something always present, that tells you the truth at a glance, and that you can
act through.**

It's worth asking why that space is empty, because it isn't an oversight. A thing that's always visible *and*
can run commands is a trust problem — it has to be right, it has to be quiet, and it has to never do something
you didn't intend. Shipping a creature that only emotes is far easier. The gap is real, and it's guarded.

## III. What we're making

Gargoyles sit on the edge of a building and watch over it. That's the whole product.

A small creature perched on the edge of your screen that shows you what your agents are doing — at a glance,
without interrupting you — and that you can act through when something needs you.

### The problem, precisely

You have six agents running across six worktrees. The expensive failure is not missing the one that finished.
It's the one that **stalled twenty minutes ago waiting for you to approve a file write**, sitting there
silently while you worked on something else. You find it when you happen to check. That's twenty minutes of
nothing, several times a day.

Nothing on your screen tells you this is happening. A terminal tab doesn't glow. Gargoyle is built for exactly
that moment.

### How it tells you

Not with a badge. Each running session is a small light the creature holds — an **ember** — and the creature's
own body carries the state:

| what's happening | what you see |
|---|---|
| four agents running | it's juggling four, absorbed, busy |
| one finishes | that ember settles and goes soft |
| **one needs you** | it stops everything and holds that ember out toward you |
| one failed | a dropped, dimmed ember on the ground beside it |
| nothing running | it pockets them and dozes |

Count, status, and urgency, with no text and no numbers. Eight agents look genuinely overwhelming, because
they are.

This is the whole design philosophy in one mechanic: **if a state can't be told through the creature's body,
it doesn't get to exist.** A badge is an admission that the character isn't doing its job.

### And you can act through it

Click the creature and the popover comes out of its body. The waiting agent is right there — approve it, or
jump straight to its terminal. Open a worktree. Start a session where you're already working. The menu knows
what you're doing and offers that first, so most of the time you don't type at all.

This is the part the genre is missing. Everything else is a face on a progress bar.

### The quieter half

It's also where everything else you care about can surface.

Anything that can produce a line of JSON becomes an ember or a question — a build, a deploy, a message that
actually matters, a script you wrote on a Tuesday afternoon. Gargoyle doesn't know what any of them are. It
knows something wants a moment of your attention, and it knows how to spend that well.

So the shape of it is yours. Someone points it at their CI. Someone wires up their gym log. Someone has it
ask, at four in the afternoon, whether they've stood up lately. Gargoyle ships none of those — it ships the
part that's actually hard, which is asking at a moment you don't mind being asked.

Every one of them waits for a natural glance instead of taking one. A nudge becoming *ready* and a nudge
becoming *visible* are two different events, and keeping them separate is the difference between a companion
and a notification.

## IV. A day with it

**8:40.** You open the laptop. It stirs, stretches, settles. Nothing is running yet — nothing to hold.

**9:15.** Three agents going in three worktrees. It's absorbed, tending them, barely moving. You're deep in
another file and you haven't consciously looked at it in twenty minutes. That's correct behavior.

**9:31.** Something moves at the edge of your vision. One arm has come out past its silhouette, holding an
ember toward you. You didn't have to be looking — motion is the one thing your peripheral vision is
excellent at.

You click. *"`api-refactor` wants to write to `src/auth/session.ts`."* You approve it. The arm draws back in
and it goes back to work. Eleven seconds, and you never left the file you were in.

**12:50.** You've been away an hour. It's asleep at the corner of the screen, drifted slightly from where you
left it.

**13:20.** You're back. It wakes, looks at your cursor, and asks — once, quietly, in a bubble that doesn't
steal focus — whether you ate. You type four words. It doesn't ask again.

**15:40.** Six agents. It's visibly frazzled, every arm occupied, colors gone warm and busy. You didn't count
them. You just know it's a lot, the same way you know a room is crowded without counting people.

**16:05.** One goes dark. A dimmed ember drops beside it and the creature looks down at it. That test suite
failed.

**19:30.** You close the laptop.

It made no sound all day.

## V. What it isn't

**Not a chatbot.** There's a text field, but it's the last resort, not the point. If you're typing sentences
at it, the menu failed.

**Not a Raycast replacement.** No clipboard history, no app launcher, no fuzzy-search everything. That fight
is already lost and it was never the interesting part. The creature's advantage is that it's *always there* —
spending that on a worse launcher would be a waste of the only thing it has.

**Not gamified.** No streaks, no XP, no levels, no leaderboard, no guilt for neglecting it. Some pets in this
genre make you feed them tokens and climb a ranking. That's a slot machine wearing a face, and it's the
opposite of what this is for.

**Not a wandering toy.** It doesn't climb your windows or run across your screen. It has a home and it stays
there, because a thing you use has to be findable and a thing that moves never is.

**Not cross-platform.** macOS, deliberately. Almost everything good here is a native system API, and the
window behavior — always visible, never stealing focus — is the one thing the portable frameworks can't do
properly.

**Not in the way.** Clicks pass through it. It never takes focus. One gesture and it's gone.

## VI. Why a creature at all

A number in your menu bar would carry the same information. So why draw an animal?

Because a number is *read* and a creature is *noticed*. Reading costs attention you have to decide to spend.
Noticing is free — it's what your peripheral vision does whether you want it to or not. A body has posture,
motion, weight, and direction, and it can carry all of them at once. Text can carry one thing, and only when
you look directly at it.

And because you're going to see this thing ten thousand times. Something you look at that often should be a
pleasure to look at. That's not decoration — over ten thousand glances, it's the entire difference between a
tool you keep and a tool you turn off.

Clippy was right about the form and wrong about the manner.

We're going to be right about both.
