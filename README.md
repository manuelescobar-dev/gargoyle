<div align="center">

# 🐙 Gargoyle

**A desktop creature that perches on the edge of your screen<br>and keeps watch over your AI coding agents.**

![status](https://img.shields.io/badge/status-design_phase-orange?style=flat-square)
![platform](https://img.shields.io/badge/platform-macOS-black?style=flat-square&logo=apple&logoColor=white)
![pet](https://img.shields.io/badge/pet-Swift_·_Rive-F05138?style=flat-square&logo=swift&logoColor=white)
![hub](https://img.shields.io/badge/hub-Node-5FA04E?style=flat-square&logo=node.js&logoColor=white)

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

## Status

Design phase — nothing is built yet. Next up is **M0**: a hub, Claude Code hooks, and a menu-bar item that
says *"2 agents need you."* No creature at all. If it doesn't earn a glance, the idea dies cheap.

## Docs

| | |
|---|---|
| [Principles](docs/principles.md) | The rules the creature has to obey |
| [Architecture](docs/architecture.md) | Hub, pet, and why each piece is what it is |
| [Creature contract](docs/creatures.md) | What it takes to add a creature to the roster |
| [Roadmap](docs/roadmap.md) | M0 → M4 |
| [Open questions](docs/open-questions.md) | Known unknowns |
| [Prior art](docs/prior-art.md) | The genre, and the gap in it |
