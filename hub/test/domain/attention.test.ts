import assert from "node:assert/strict";
import { test } from "node:test";
import { levelFor, type Surroundings } from "../../src/domain/attention.ts";

const calm: Surroundings = { moment: "", busy: false, undisturbed: false };
const glancing: Surroundings = { ...calm, moment: "glance" };

// The ladder, top to bottom. Everything that wants attention passes through here, so the
// noise level is one thing you can tune rather than a dozen scattered conditions.

test("the body changing is never louder than silent", () => {
  assert.equal(levelFor({ kind: "state" }, calm), "silent");
  assert.equal(levelFor({ kind: "state" }, glancing), "silent");
  assert.equal(levelFor({ kind: "state" }, { ...calm, busy: true }), "silent");
});

test("a blocked agent is a badge, not an interruption", () => {
  assert.equal(levelFor({ kind: "blocked", waitedMs: 0 }, calm), "badge");
});

// The arm is already waving. Escalating is for when that plainly hasn't worked.
test("a blocked agent escalates only after being ignored a long time", () => {
  assert.equal(levelFor({ kind: "blocked", waitedMs: 60_000 }, calm), "badge");
  assert.equal(levelFor({ kind: "blocked", waitedMs: 11 * 60_000 }, calm), "notify");
});

test("nothing speaks unless you're already looking", () => {
  assert.equal(levelFor({ kind: "voice", situation: "failed" }, calm), "silent");
  assert.equal(levelFor({ kind: "voice", situation: "failed" }, glancing), "bubble");
});

test("a nudge waits for a glance too", () => {
  assert.equal(levelFor({ kind: "nudge" }, calm), "silent");
  assert.equal(levelFor({ kind: "nudge" }, glancing), "bubble");
});

test("nothing chats at you while an agent is waiting", () => {
  const busy = { ...glancing, busy: true };
  assert.equal(levelFor({ kind: "nudge" }, busy), "silent");
  assert.equal(levelFor({ kind: "voice", situation: "failed" }, busy), "silent");
});

// Fullscreen, presenting, watching something. The closest thing to Focus we can read.
test("undisturbed silences everything conversational", () => {
  const undisturbed = { ...glancing, undisturbed: true };
  assert.equal(levelFor({ kind: "nudge" }, undisturbed), "silent");
  assert.equal(levelFor({ kind: "voice", situation: "failed" }, undisturbed), "silent");
});

test("but a badge still shows — it costs nothing to look at", () => {
  const undisturbed = { ...calm, undisturbed: true };
  assert.equal(levelFor({ kind: "blocked", waitedMs: 0 }, undisturbed), "badge");
});

test("and nothing ever escalates to a notification while you're presenting", () => {
  const undisturbed = { ...calm, undisturbed: true };
  assert.equal(
    levelFor({ kind: "blocked", waitedMs: 60 * 60_000 }, undisturbed),
    "badge",
    "an hour of waiting still doesn't earn a popup over a presentation",
  );
});

test("sound is not on the ladder at all", () => {
  const everything = [
    levelFor({ kind: "state" }, glancing),
    levelFor({ kind: "blocked", waitedMs: 99 * 60_000 }, glancing),
    levelFor({ kind: "voice", situation: "failed" }, glancing),
    levelFor({ kind: "nudge" }, glancing),
  ];
  assert.ok(!everything.includes("sound" as never), "almost never means not yet");
});
