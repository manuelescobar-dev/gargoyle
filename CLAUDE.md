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

**Never invent a state the hub can't honestly produce.** `asleep` and `listening` are in the
vocabulary and deliberately unreachable — no user-idle detection, no push-to-talk yet. A state we
can't honestly produce doesn't get faked.

**A state must differ *visibly*, not just numerically.** `unknown` and `idle` once passed a `!=`
test while rendering identically. Assert the difference you'd see at 48px in your peripheral vision.

**One dependency total** — `ws` in the hub. The pet has none. A second needs a decision record
arguing for it.

**No verticals.** Gargoyle ships the attention model and the Claude Code integration, nothing else.
Anything can POST to `/event`. See [decisions/0005](decisions/0005-a-surface-not-a-suite.md).

## TypeScript without a build step

Node runs `.ts` directly by stripping types, which means **only syntax that erases** is
allowed. No parameter properties (`constructor(private x: T)`), no `enum`, no `namespace`,
no decorators — anything that emits runtime code fails at load with
`ERR_UNSUPPORTED_TYPESCRIPT_SYNTAX`. Use plain fields, `const` objects, and `as const`.

## Tests

TDD. Write the failing test first. **A bug fix must include a test that fails on the buggy code and
passes on the fix** — no exceptions, and it goes at the layer where the bug lived.

Coverage is proportional to risk, not to a percentage. Full reasoning in
[ENGINEERING.md](ENGINEERING.md#testing).

## Commands

```bash
cd hub && npm test        # 51 tests
cd hub && npm run check   # biome, formats and lints
cd hub && npm start       # hub on 127.0.0.1:7373

cd pet && swift test      # 38 tests

# regenerate the creature previews after changing how it's drawn
cd pet && GARGOYLE_RENDER_PREVIEWS=1 swift test --filter renderPreviews
cd pet && swift run Gargoyle
```

Both suites assert against `protocol/fixtures/state.json` — the hub that it still
produces that shape, the pet that it still decodes it. Change the protocol and you
change that file, or one side goes quiet without failing.

## Layout

```
hub/src/domain/    what the creature shows. knows nothing about sources or transport
hub/src/sources/   vendor payload → domain Event. the only place Claude Code is named
hub/src/server.ts  HTTP boundary
pet/…/Domain/      Snapshot, CreatureInputs, OctopusPose. pure — no AppKit, no networking
pet/…/Transport/   HubConnection. the socket, and nothing else
pet/…/UI/          AppKit only. draws a pose, decides nothing
creatures/         per creature: a persona.md, and previews rendered from the code
protocol/          the hub↔pet wire format
decisions/         why things are the way they are
docs/              the story and the principles. no implementation detail lives here
```
