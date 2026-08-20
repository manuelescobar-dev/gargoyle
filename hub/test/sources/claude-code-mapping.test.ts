import assert from "node:assert/strict";
import { test } from "node:test";
import { fromClaudeHook } from "../../src/sources/claude-code.ts";
import { Sessions } from "../../src/domain/sessions.ts";
import { snapshot } from "../../src/domain/state.ts";

const hook = (name: string, id = "s1") =>
  fromClaudeHook({ hook_event_name: name, session_id: id, cwd: "/w/x" });

const stateAfter = (...names: string[]) => {
  const sessions = new Sessions();
  for (const n of names) {
    const e = hook(n);
    if (e) sessions.apply(e);
  }
  return snapshot(sessions.list()).state;
};

test("PermissionRequest is the precise blocked signal", () => {
  assert.equal(hook("PermissionRequest")?.type, "blocked");
  assert.equal(stateAfter("SessionStart", "PermissionRequest"), "needs-you");
});

test("PermissionDenied unblocks — you answered, it moves on", () => {
  assert.equal(stateAfter("PermissionRequest", "PermissionDenied"), "working");
});

// Notification fires for auth_success and agent_completed too. Treating every
// notification as "blocked" would have the creature demanding attention because
// a login succeeded.
test("Notification is not treated as blocked on its own", () => {
  assert.notEqual(
    hook("Notification")?.type,
    "blocked",
    "the installer narrows Notification by matcher; the parser must not assume",
  );
});

test("StopFailure means the turn died — that's failed, not done", () => {
  assert.equal(hook("StopFailure")?.type, "failed");
  assert.equal(stateAfter("SessionStart", "StopFailure"), "failed");
});

// A failing test suite or a grep that finds nothing is routine agent work.
// Calling it a failed run would be the creature lying about state.
test("a failed tool call is not a failed session", () => {
  assert.notEqual(hook("PostToolUseFailure")?.type, "failed");
  assert.equal(stateAfter("SessionStart", "PostToolUseFailure"), "working");
});

test("blocked still outranks failed", () => {
  const sessions = new Sessions();
  for (const [name, id] of [["StopFailure", "a"], ["PermissionRequest", "b"]] as const) {
    const e = fromClaudeHook({ hook_event_name: name, session_id: id, cwd: "/w/x" });
    if (e) sessions.apply(e);
  }
  assert.equal(snapshot(sessions.list()).state, "needs-you");
});

test("SubagentStart keeps the session active", () => {
  assert.equal(hook("SubagentStart")?.type, "active");
});
