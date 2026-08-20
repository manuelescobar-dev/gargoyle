# Working in this repo

Gargoyle is a desktop creature that keeps watch over your AI coding agents.
Read [docs/principles.md](docs/principles.md) first — those values decide arguments, and most
disagreements here are settled by pointing at one.

## Before you write code

**Plan first.** Enter plan mode and present the approach — files touched, the layering, the test
plan — before editing anything. This project has far more design than code, and the wrong shape
costs a sentence to fix in a plan and a rewrite to fix in review.

**Check `decisions/`.** Before relitigating the stack, the protocol, or the scope: it's written
down, with the reasoning and with what would change our mind. Add to it rather than arguing twice.

## Rules that don't bend

**Dependencies point inward.** `src/domain/` must never import from `src/sources/` or from
transport. Enforced by `test/architecture.test.ts` — it fails loudly, and that's deliberate.

**Every source normalizes to `domain/event.ts`.** A coding agent, a cron job and an iOS Shortcut all
arrive as the same shape. Only files in `src/sources/` may know what a vendor payload looks like.

**The pet owns zero logic.** It renders the snapshot it receives and keeps nothing. The one
exception is entering `unknown` when the socket drops — see
[decisions/0003](decisions/0003-snapshots-not-diffs.md).

**Never invent a state the hub can't honestly produce.** `failed` is unreachable today because the
Stop hook doesn't report success. Three honest statuses beat four with one guessed.

**Two dependencies total** — Rive in the pet, `ws` in the hub. A third needs a decision record
arguing for it.

**No verticals.** Gargoyle ships the attention model and the Claude Code integration, nothing else.
Anything can POST to `/event`. See [decisions/0005](decisions/0005-a-surface-not-a-suite.md).

## Tests

TDD. Write the failing test first. **A bug fix must include a test that fails on the buggy code and
passes on the fix** — no exceptions, and it goes at the layer where the bug lived.

Coverage is proportional to risk, not to a percentage. Full reasoning in
[CONTRIBUTING.md](CONTRIBUTING.md#testing).

## Commands

```bash
cd hub
npm test          # node --test, 18 tests
npm run check     # biome, formats and lints
npm start         # hub on 127.0.0.1:7373
```

## Layout

```
hub/src/domain/    what the creature shows. knows nothing about sources or transport
hub/src/sources/   vendor payload → domain Event. the only place Claude Code is named
hub/src/server.ts  HTTP boundary
creatures/         one folder per creature: a .riv and a persona.md
protocol/          the hub↔pet wire format
decisions/         why things are the way they are
docs/              the story and the principles. no implementation detail lives here
```
