import assert from "node:assert/strict";
import { test } from "node:test";
import { menuFor } from "../../src/domain/menu.ts";
import type { Snapshot } from "../../src/domain/state.ts";

const now = 1_000_000;
const ember = (
  id: string,
  label: string,
  status: Snapshot["embers"][0]["status"],
  sinceMs: number,
  focusable = true,
) => ({ id, label, status, since: now - sinceMs, focusable });
const snap = (embers: Snapshot["embers"]): Snapshot => ({
  state: embers.some((e) => e.status === "blocked") ? "needs-you" : "working",
  embers,
  mood: 0,
  blocked: embers.filter((e) => e.status === "blocked").length,
});

// Longest wait first: that's the one whose cost has been growing the longest, which is the
// whole problem Gargoyle exists to catch.
test("whatever has been waiting longest comes first", () => {
  const items = menuFor(
    snap([
      ember("a", "recent", "blocked", 5_000),
      ember("b", "stale", "blocked", 240_000),
      ember("c", "running", "running", 1_000),
    ]),
    { now },
  );
  assert.equal(items[0].id, "focus:b");
  assert.equal(items[1].id, "focus:a");
});

test("blocked always outranks running, however long it's been", () => {
  const items = menuFor(
    snap([ember("a", "old-run", "running", 900_000), ember("b", "new-block", "blocked", 1_000)]),
    { now },
  );
  assert.equal(items[0].id, "focus:b");
});

test("the label says how long it's been waiting", () => {
  const items = menuFor(snap([ember("a", "billing", "blocked", 245_000)]), { now });
  assert.match(items[0].label, /billing/);
  assert.match(items[0].label, /4m/, "four minutes of silence is the thing worth knowing");
});

test("a fresh block doesn't claim a duration yet", () => {
  const items = menuFor(snap([ember("a", "billing", "blocked", 2_000)]), { now });
  assert.doesNotMatch(items[0].label, /\dm/, "'waiting 0m' is noise");
});

// You're already looking at it, so jumping there is the least useful row on the list.
test("the terminal you're already in drops to the bottom", () => {
  const embers = [ember("a", "here", "running", 1_000), ember("b", "elsewhere", "running", 2_000)];
  const items = menuFor(snap(embers), { now, currentSession: "a" });
  assert.equal(items[items.length - 1].id, "focus:a");
});

test("but not if it's the one that needs you", () => {
  const embers = [ember("a", "here", "blocked", 60_000), ember("b", "elsewhere", "running", 1_000)];
  const items = menuFor(snap(embers), { now, currentSession: "a" });
  assert.equal(items[0].id, "focus:a", "being in the tab doesn't answer the question");
});

test("no context is fine — it just doesn't reorder anything", () => {
  const items = menuFor(snap([ember("a", "one", "running", 1_000)]), { now });
  assert.equal(items.length, 1);
});

test("nothing running means nothing to jump to", () => {
  assert.deepEqual(menuFor(snap([]), { now }), []);
});

// The pet knows which terminal is frontmost; only the hub knows which agent runs there.
test("a terminal id is matched to its session by suffix", () => {
  const embers = [
    ember("s1", "here", "running", 1_000),
    ember("s2", "elsewhere", "running", 5_000),
  ];
  // `w12t0p0:UUID` from the shell, bare `UUID` from AppleScript — matching is by suffix.
  const items = menuFor(snap(embers), { now, currentSession: "s1" });
  assert.equal(items[items.length - 1].id, "focus:s1");
});

// Sources that aren't agents still show as embers — the creature holds them the same way —
// but there's nowhere to jump to, and a row that does nothing is its own small lie.
test("something with no terminal gets no jump row", () => {
  const items = menuFor(
    snap([
      ember("ci", "nightly build", "running", 1_000, false),
      ember("s1", "api-refactor", "running", 2_000),
    ]),
    { now },
  );
  assert.deepEqual(
    items.map((i) => i.id),
    ["focus:s1"],
  );
});

test("a blocked source with no terminal still doesn't get a row", () => {
  const items = menuFor(snap([ember("ci", "build", "blocked", 90_000, false)]), { now });
  assert.deepEqual(items, [], "it's on the creature, just not jumpable");
});
