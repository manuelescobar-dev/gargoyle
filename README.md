<div align="center">

# 🐙 Gargoyle

**A desktop creature that perches on the edge of your screen<br>and keeps watch over your AI coding agents.**

![status](https://img.shields.io/badge/status-design_phase-orange?style=flat-square)
![platform](https://img.shields.io/badge/platform-macOS-black?style=flat-square&logo=apple&logoColor=white)

</div>

---

Gargoyles sit on the edge of a structure and watch over it. That's the whole product: a small creature
anchored to your screen edge that shows you, at a glance and without interrupting you, what your agents are
doing — and lets you act on them without hunting through terminal windows.

## What you see

Each running session is a small light the creature holds — an **ember**.

| situation | what you see |
|---|---|
| 4 agents running | it's juggling four, absorbed, busy |
| one finishes | that ember settles and goes soft |
| **one needs you** | it stops everything and holds that ember out toward you |
| one failed | a dropped, dimmed ember on the ground beside it |
| nothing running | it pockets them and dozes |

Count, status, and urgency, with zero text and zero badges. Eight agents should look genuinely overwhelming,
because it is.

## What makes it different

**Physiology, not badges.** Most desktop pets are a sprite with a notification dot bolted on. Here the
creature's body *is* the display — if a state can't be expressed through anatomy and behavior, it doesn't get
a state.

**Built for peripheral vision.** Your periphery is nearly colorblind but extremely motion-sensitive, so
"needs you" is a motion pattern that breaks the silhouette, never a red dot. Color is for when you're already
looking; motion is for when you're not.

**It watches for the stall.** The expensive failure across a dozen worktrees isn't missing a finished run —
it's the agent that silently blocked on a permission prompt 20 minutes ago. That's the one Gargoyle is built
to catch.

**It works both ways.** Every pet in this genre is output-only. Click this one and act: focus the waiting
terminal, approve the prompt, open a worktree.

## Quickstart

Requires [Node 24+](https://nodejs.org) and macOS 14+.

```bash
git clone https://github.com/manuelescobar-dev/gargoyle
cd gargoyle/hub && npm install
node src/cli.ts install
```

That wires Claude Code's hooks to the hub and sets the hub to start at login. It appends
to your hooks rather than replacing them, backs up `settings.json` first, and is safe to
run twice.

Then start the surface:

```bash
cd ../pet && swift run Gargoyle
```

Check it's actually working — the useful part is that it can tell "wired up" from
"wired up and never fired":

```bash
cd ../hub && node src/cli.ts doctor
```

## Anything can be an ember

Gargoyle ships the attention model and the Claude Code integration, and nothing else.
Everything you care about gets in through one line:

```bash
curl -X POST localhost:7373/event -d '{"id":"ci","label":"nightly build","status":"running"}'
curl -X POST localhost:7373/event -d '{"id":"ci","status":"done"}'
```

`running` · `blocked` · `done` · `failed` · `gone`. A blocked source raises the creature's
arm exactly like a blocked agent does. No SDK, no plugin API — a shell script, a cron job,
an iOS Shortcut and another app all arrive the same way.

## And anything can ask you something

```bash
curl -X POST localhost:7373/nudge \
  -d '{"text":"what did you eat?","reply_to":"~/bin/log-food"}'
```

The creature asks **when you're already looking at it** — you clicked it, a run just
finished, you came back to a terminal — never when a timer fires. Your answer goes to the
command you named. Gargoyle stores nothing itself.

That's the whole of it: Gargoyle ships the part that's hard, which is asking at a moment
you don't mind being asked.

## Using it with OpenClaw

No plugin, no package — the two doors are enough. Point a skill or cron job at `/nudge`, and
send the answer back with `openclaw agent`:

```bash
curl -s -X POST localhost:7373/nudge \
  -d '{"text":"what did you eat?","reply_to":"openclaw agent -m \"$(cat)\""}'
```

Gargoyle asks when you're already looking, your answer becomes an agent turn, and Gargoyle
stores none of it. It works just as well without OpenClaw — it never learned OpenClaw exists.

To disconnect completely:

```bash
node src/cli.ts uninstall
```

Your own hooks and settings are left exactly as they were.

## Status

**M0 works.** The hub reads Claude Code's hooks, pushes state over a socket, and a menu
bar item shows what needs you — including telling "the hub is gone" apart from "all quiet."

**M1 is underway.** The floating panel, the creature input contract, and the failed-run
detection are done. What's left is the creature itself, which needs someone to draw it in
the Rive editor ([#9](https://github.com/manuelescobar-dev/gargoyle/issues/9)).

## Docs

| | |
|---|---|
| [The story](docs/story.md) | Where desktop creatures came from, the gap none of them fill, and what we're making |
| [Principles](docs/principles.md) | The values the project lives by, and the rules that fall out of them |

## License

MIT — see [LICENSE](LICENSE).
