import assert from "node:assert/strict";
import { test } from "node:test";
import type { Snapshot } from "../../src/domain/state.ts";
import { situationFor } from "../../src/domain/voice.ts";

const snap = (state: Snapshot["state"], running = 0, blocked = 0): Snapshot => ({
  state,
  embers: [
    ...Array.from({ length: running }, (_, i) => ({
      id: `r${i}`,
      label: "w",
      status: "running" as const,
    })),
    ...Array.from({ length: blocked }, (_, i) => ({
      id: `b${i}`,
      label: "w",
      status: "blocked" as const,
    })),
  ],
  mood: 0,
  blocked,
});

test("a failed run is worth saying out loud", () => {
  assert.equal(situationFor(snap("working", 2), snap("failed")), "failed");
});

test("finishing the last one is worth a word", () => {
  assert.equal(situationFor(snap("working", 1), snap("idle")), "idle");
});

test("getting swamped is worth a word", () => {
  assert.equal(situationFor(snap("working", 4), snap("working", 6)), "busy");
});

// The creature is something you look at, not something that talks to you. Everything
// below is already visible on its body, so saying it too would be noise.
test("it stays quiet for things its body already shows", () => {
  assert.equal(situationFor(snap("idle"), snap("working", 1)), null, "starting a run");
  assert.equal(
    situationFor(snap("working", 2), snap("needs-you", 1, 1)),
    null,
    "the arm says this",
  );
  assert.equal(situationFor(snap("working", 2), snap("working", 3)), null, "one more agent");
});

test("it doesn't repeat itself while nothing changes", () => {
  assert.equal(situationFor(snap("failed"), snap("failed")), null);
  assert.equal(situationFor(snap("working", 7), snap("working", 8)), null, "already said busy");
});

test("with nothing before it, it says nothing", () => {
  assert.equal(situationFor(null, snap("working", 3)), null, "no comment on arriving mid-stream");
});
