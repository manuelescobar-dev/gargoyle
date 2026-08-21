import assert from "node:assert/strict";
import { test } from "node:test";
import { fromClaudeHook } from "../../src/sources/claude-code.ts";

test("a real hook payload normalizes", () => {
  const e = fromClaudeHook(
    { hook_event_name: "PermissionRequest", session_id: "abc", cwd: "/w/x" },
    1234,
  );
  assert.deepEqual(e, {
    source: "claude-code",
    sessionId: "abc",
    cwd: "/w/x",
    type: "blocked",
    ts: 1234,
    terminal: undefined,
  });
});

test("the terminal the hook ran in comes through", () => {
  const e = fromClaudeHook(
    { hook_event_name: "Stop", session_id: "abc", cwd: "/w/x" },
    1,
    { app: "iTerm.app", term: "w1t0p0:UUID" },
  );
  assert.equal(e?.terminal?.app, "iTerm.app");
  assert.equal(e?.terminal?.term, "w1t0p0:UUID");
});

// Every agent on the machine posts here. Anything unrecognised has to be survivable,
// not fatal — a new Claude Code version must never be able to take the hub down.
for (const [name, payload] of [
  ["an unknown hook name", { hook_event_name: "SomethingNew2027", session_id: "a" }],
  ["a payload with no session id", { hook_event_name: "Stop" }],
  ["null", null],
  ["a string", "nope"],
  ["an empty object", {}],
] as const) {
  test(`${name} is ignored, not thrown`, () => {
    assert.equal(fromClaudeHook(payload), null);
  });
}

test("a missing cwd degrades to an empty string rather than failing", () => {
  const e = fromClaudeHook({ hook_event_name: "Stop", session_id: "a" });
  assert.equal(e?.cwd, "");
});
