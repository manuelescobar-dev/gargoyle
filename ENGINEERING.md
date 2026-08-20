# Engineering guidelines

How code in this repo is structured and tested. Applies to everything here, contribution or not.
For the mechanics of opening a PR, see [CONTRIBUTING.md](CONTRIBUTING.md).

## The shape of the work

Gargoyle is deliberately small: **one creature, one attention system, one deep integration, and
everything else is a `curl`.** Most feature requests should be answered with "that's a source" and a
three-line example. That's not deflection — it's [decision 0005](decisions/0005-a-surface-not-a-suite.md)
working as intended.

Before proposing something, read [docs/principles.md](docs/principles.md). The values there settle
most arguments faster than a discussion will.

## Testing

### Proportional to risk

Tests scale to the risk of the change, not to a checklist or a coverage number.

- **Pure, low-risk function** → one or two tests.
- **Branching, IO, or shared state** → behavior tests with the edge cases: empty input, error path,
  boundary, concurrency.
- **New public surface or cross-boundary change** → behavior tests *and* something end-to-end.

Don't drown a trivial change to hit a number, and don't leave a risky one bare because it's small.

### Behavioral, not trivial

Test observable behavior. A good test still passes after the implementation is refactored.

Two questions for any test:

- Would this still pass after a reasonable refactor? If no, it tests the implementation, not the
  behavior.
- What edge case would silently break in production — is it covered?

Mocking is fine as long as the assertion is on observable output, never on "was this internal
method called."

### Bug fixes are TDD, always

A bug fix **must** ship with a test that fails on the buggy code and passes on the fix, at the layer
where the bug actually lived. A bug in the session registry gets a registry test, not an end-to-end
test that happens to exercise it.

If the bug was in a dependency's behavior, the regression test hits the real dependency. A mock
would have hidden it in the first place.

### Structural tests

Some rules are too easy to break by accident to be left to discipline. Those get a test that scans
the source and fails on violation — see `hub/test/architecture.test.ts`, which enforces that the
domain never imports from a source or from transport.

If you add a registry, a fallback chain, or another convention that "everyone just knows," make it
impossible by construction instead.

## Architecture

Clean architecture's useful half, without the ceremony.

```
sources/  ──→  domain/  ←──  server.ts
   adapters      the rules      transport
```

**Dependencies point inward.** `domain/` decides what the creature shows. It must never learn that
Claude Code exists, or that there's HTTP involved. Sources and transport depend on the domain; the
domain depends on nothing.

**One event shape.** Every source normalizes to `domain/event.ts` at the boundary. This is what lets
a cron job, an unread message and a coding agent all become embers without the state machine
learning anything new.

**No layer that isn't earning its keep.** We don't have use-case objects, repositories or
interactors, because at this size they'd be ceremony. If a file would do, use a file — that's
*boring code, interesting creature* applied to ourselves.

## Adding a source

You almost certainly don't need to. `POST /event` accepts anything that produces JSON:

```bash
curl -X POST localhost:7373/event -d '{"id":"ci","label":"build","status":"running"}'
```

A source only belongs in `src/sources/` when it needs depth the endpoint can't give — the way Claude
Code does, because it has to map sessions to worktrees and answer blocked permission prompts.

## Adding a creature

Authoring, not coding. If you have to touch Swift to add a creature, the contract has failed.
See [creatures/README.md](creatures/README.md) for the nine states, the Rive input table, and the
persona format.

The only test that really matters: shrink it to 48px, blur it, look away. If you can't tell
`working` from `needs-you`, redraw it.

## Commits

Say *why*, not *what* — the diff already covers what. When a commit encodes a judgment call, put the
reasoning in the message, and if it's a decision that would be expensive to revisit, write it up in
`decisions/` instead.
