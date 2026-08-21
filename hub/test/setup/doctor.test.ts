import assert from "node:assert/strict";
import { test } from "node:test";
import { diagnose } from "../../src/setup/doctor.ts";

const healthy = { hubUp: true, hooksWired: true, agentLoaded: true, eventsSeen: 42 };

test("everything working reports healthy", () => {
  const { ok, lines } = diagnose(healthy);
  assert.equal(ok, true);
  assert.ok(lines.every((l) => l.startsWith("✓")));
});

test("a hub that's down is the headline, not a footnote", () => {
  const { ok, lines } = diagnose({ ...healthy, hubUp: false });
  assert.equal(ok, false);
  assert.match(lines[0], /^✗/);
  assert.match(lines[0], /hub/i);
});

// The nastiest state to be in: everything looks installed, so you assume it works,
// but nothing has ever actually arrived. Silence must not read as health.
test("wired but never fired is called out explicitly", () => {
  const { ok, lines } = diagnose({ ...healthy, eventsSeen: 0 });
  assert.equal(ok, false);
  assert.ok(
    lines.some((l) => l.startsWith("✗") && /no events/i.test(l)),
    "zero events with everything wired is a failure, not a clean bill of health",
  );
});

test("a single event isn't reported as '1 events'", () => {
  const { lines } = diagnose({ ...healthy, eventsSeen: 1 });
  assert.ok(lines.some((l) => l === "✓ 1 event received"));
});

test("missing hooks explains how to fix it", () => {
  const { lines } = diagnose({ ...healthy, hooksWired: false });
  assert.ok(lines.some((l) => l.includes("install-hooks") || l.includes("install")));
});

test("an unloaded agent is a warning, not a failure — you can run the hub by hand", () => {
  const { ok, lines } = diagnose({ ...healthy, agentLoaded: false });
  assert.equal(ok, true, "the hub is up, which is what actually matters");
  assert.ok(lines.some((l) => l.startsWith("·")));
});

// The creature not running isn't a broken install — the hub is still doing its job, and
// plenty of people would rather launch it themselves.
test("a missing creature is worth knowing, not a failure", () => {
  const { ok, lines } = diagnose({ ...healthy, creatureRunning: false });
  assert.equal(ok, true);
  assert.ok(lines.some((l) => l.startsWith("·") && /creature/.test(l)));
});

test("a running creature is reported", () => {
  const { lines } = diagnose({ ...healthy, creatureRunning: true });
  assert.ok(lines.some((l) => l === "✓ creature is on screen"));
});
