import assert from "node:assert/strict";
import { test } from "node:test";
import { fromClaudeHook } from "../src/events.ts";
import { DONE_TTL_MS, Sessions } from "../src/sessions.ts";
import { snapshot } from "../src/state.ts";

/** Builds a Claude Code hook payload the way the real hook sends it. */
const hook = (name: string, id: string, cwd = "/w/api-refactor") => ({
  hook_event_name: name,
  session_id: id,
  cwd,
});

const feed = (s: Sessions, ...events: ReturnType<typeof hook>[]) => {
  for (const e of events) {
    const ev = fromClaudeHook(e);
    if (ev) s.apply(ev);
  }
  return s;
};

test("no sessions reads as idle", () => {
  assert.equal(snapshot([]).state, "idle");
});

test("a running session reads as working", () => {
  const s = feed(new Sessions(), hook("SessionStart", "a"));
  assert.equal(snapshot(s.list()).state, "working");
});

test("one blocked session outranks any number of running ones", () => {
  const s = feed(
    new Sessions(),
    hook("SessionStart", "a"),
    hook("SessionStart", "b"),
    hook("SessionStart", "c"),
    hook("Notification", "d"),
  );
  const snap = snapshot(s.list());
  assert.equal(snap.state, "needs-you", "blocked must win — its cost grows while you don't look");
  assert.equal(snap.blocked, 1);
  assert.equal(snap.embers.length, 4);
});

test("a session that unblocks goes back to working", () => {
  const s = feed(new Sessions(), hook("Notification", "a"), hook("PreToolUse", "a"));
  assert.equal(snapshot(s.list()).state, "working");
});

test("a blocked session keeps the timestamp it blocked at", () => {
  const s = new Sessions();
  s.apply({ source: "c", sessionId: "a", cwd: "/w/x", type: "blocked", ts: 1000 });
  s.apply({ source: "c", sessionId: "a", cwd: "/w/x", type: "blocked", ts: 9000 });
  assert.equal(s.list()[0].since, 1000, "we need to know how long you've been holding it up");
});

test("a finished session shows briefly, then stops being interesting", () => {
  const s = new Sessions();
  s.apply({ source: "c", sessionId: "a", cwd: "/w/x", type: "finished", ts: 0 });

  s.prune(DONE_TTL_MS - 1);
  assert.equal(snapshot(s.list()).state, "done");

  s.prune(DONE_TTL_MS + 1);
  assert.equal(snapshot(s.list()).state, "idle");
});

test("SessionEnd removes the session outright", () => {
  const s = feed(new Sessions(), hook("SessionStart", "a"), hook("SessionEnd", "a"));
  assert.deepEqual(s.list(), []);
});

test("embers are labelled by worktree, which is how you think about them", () => {
  const s = feed(new Sessions(), hook("SessionStart", "a", "/Users/m/code/api-refactor"));
  assert.equal(snapshot(s.list()).embers[0].label, "api-refactor");
});

test("mood climbs with load and saturates", () => {
  const s = new Sessions();
  assert.equal(snapshot(s.list()).mood, 0);
  for (let i = 0; i < 3; i++) feed(s, hook("SessionStart", `s${i}`));
  assert.equal(snapshot(s.list()).mood, 0.5);
  for (let i = 3; i < 12; i++) feed(s, hook("SessionStart", `s${i}`));
  assert.equal(
    snapshot(s.list()).mood,
    1,
    "must saturate — twelve agents can't be worse than frazzled",
  );
});
