# CI

Two jobs, because the halves have nothing in common: the hub is Node on Linux, the pet is
AppKit on macOS.

Both suites assert against `protocol/fixtures/state.json`. That's the point of running them
together — the fixture is the only thing stopping the two languages from drifting apart
silently, and it can only do that job if something checks it without being asked.
