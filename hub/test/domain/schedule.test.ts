import assert from "node:assert/strict";
import { test } from "node:test";
import { dueNow, parseEvery } from "../../src/domain/schedule.ts";

test("intervals read the way you'd write them", () => {
  assert.equal(parseEvery("30s"), 30_000);
  assert.equal(parseEvery("5m"), 300_000);
  assert.equal(parseEvery("2h"), 7_200_000);
});

test("nonsense is refused rather than turned into a surprise interval", () => {
  for (const bad of ["", "soon", "5", "m5", "-5m", "5x"]) {
    assert.equal(parseEvery(bad), null, bad);
  }
});

// A source firing every second would be a hub that costs something while doing nothing.
test("an absurdly short interval is refused", () => {
  assert.equal(parseEvery("1s"), null);
  assert.equal(parseEvery("10s"), 10_000, "ten seconds is the floor");
});

const source = { run: "x", everyMs: 60_000 };

test("something never run is due immediately", () => {
  assert.equal(
    dueNow(source, { now: 1000, lastRunAt: undefined, running: false, busy: false }),
    true,
  );
});

test("it waits out its interval", () => {
  assert.equal(dueNow(source, { now: 30_000, lastRunAt: 0, running: false, busy: false }), false);
  assert.equal(dueNow(source, { now: 61_000, lastRunAt: 0, running: false, busy: false }), true);
});

// A slow source must not stack up copies of itself.
test("a source still running doesn't start again", () => {
  assert.equal(dueNow(source, { now: 999_999, lastRunAt: 0, running: true, busy: false }), false);
});

// Gating matters more than scheduling — an unconditional cron is the trigger of last resort.
test("nothing new starts while an agent needs you", () => {
  assert.equal(dueNow(source, { now: 999_999, lastRunAt: 0, running: false, busy: true }), false);
});

test("a source can opt out of that gate when it's genuinely urgent", () => {
  const urgent = { run: "x", everyMs: 60_000, whenBusy: true };
  assert.equal(dueNow(urgent, { now: 999_999, lastRunAt: 0, running: false, busy: true }), true);
});
