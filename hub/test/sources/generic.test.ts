import assert from "node:assert/strict";
import { test } from "node:test";
import { fromGeneric } from "../../src/sources/generic.ts";

test("a shell script can post an ember with no ceremony", () => {
  const e = fromGeneric({ id: "ci", label: "build", status: "running" }, 5);
  assert.deepEqual(e, {
    source: "external",
    sessionId: "ci",
    cwd: "",
    type: "active",
    ts: 5,
    label: "build",
    terminal: undefined,
  });
});

test("the status vocabulary is the same one agents use", () => {
  const cases = [
    ["running", "active"],
    ["blocked", "blocked"],
    ["done", "finished"],
    ["failed", "failed"],
    ["gone", "ended"],
  ] as const;
  for (const [status, expected] of cases) {
    assert.equal(fromGeneric({ id: "x", status }, 1)?.type, expected, status);
  }
});

test("a label is optional and falls back to the id", () => {
  assert.equal(fromGeneric({ id: "ci", status: "running" }, 1)?.label, "ci");
});

test("a source can name itself", () => {
  assert.equal(fromGeneric({ id: "x", status: "running", source: "ci" }, 1)?.source, "ci");
});

// This endpoint is open to anything on the machine. Nothing posted to it may take the hub
// down, and nothing ambiguous should be guessed at.
for (const [name, payload] of [
  ["no id", { status: "running" }],
  ["no status", { id: "x" }],
  ["an invented status", { id: "x", status: "reticulating" }],
  ["an id that isn't a string", { id: 42, status: "running" }],
  ["null", null],
  ["a string", "nope"],
  ["a Claude hook payload", { hook_event_name: "Stop", session_id: "s1" }],
] as const) {
  test(`${name} is refused, not guessed at`, () => {
    assert.equal(fromGeneric(payload, 1), null);
  });
}

test("an absurd id is refused rather than filling the creature's arms", () => {
  assert.equal(fromGeneric({ id: "x".repeat(500), status: "running" }, 1), null);
});
