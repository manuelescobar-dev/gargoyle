import assert from "node:assert/strict";
import { test } from "node:test";
import { menuFor } from "../../src/domain/menu.ts";
import type { Snapshot } from "../../src/domain/state.ts";

const snap = (embers: Array<[string, string, Snapshot["embers"][0]["status"]]>): Snapshot => ({
  state: embers.some(([, , s]) => s === "blocked") ? "needs-you" : "working",
  embers: embers.map(([id, label, status]) => ({ id, label, status })),
  mood: 0,
  blocked: embers.filter(([, , s]) => s === "blocked").length,
});

test("what's blocking you comes first", () => {
  const items = menuFor(snap([
    ["s1", "api-refactor", "running"],
    ["s2", "billing-fix", "blocked"],
  ]));
  assert.match(items[0].label, /billing-fix/);
  assert.equal(items[0].id, "focus:s2");
});

test("every blocked agent gets its own row", () => {
  const items = menuFor(snap([
    ["a", "one", "blocked"],
    ["b", "two", "blocked"],
    ["c", "three", "running"],
  ]));
  assert.equal(items.filter((i) => i.id.startsWith("focus:")).length, 3, "running ones are reachable too");
  assert.deepEqual(items.slice(0, 2).map((i) => i.id), ["focus:a", "focus:b"]);
});

test("labels name the worktree, which is how you think about them", () => {
  assert.match(menuFor(snap([["s1", "billing-fix", "blocked"]]))[0].label, /billing-fix/);
});

test("nothing running means nothing to jump to", () => {
  assert.deepEqual(menuFor(snap([])), []);
});

test("ids carry the session, so the pet never has to work out which is which", () => {
  const items = menuFor(snap([["abc123", "w", "running"]]));
  assert.equal(items[0].id, "focus:abc123");
});
