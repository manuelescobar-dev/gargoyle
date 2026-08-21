import assert from "node:assert/strict";
import { test } from "node:test";
import { NudgeQueue } from "../../src/domain/nudges.ts";

const now = 1_000_000;

test("a queued nudge waits rather than firing", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "what did you eat?" }, now);
  assert.equal(queue.size, 1);
});

// The whole point. A nudge becoming *eligible* and becoming *visible* are two different
// events, and keeping them apart is the difference between a companion and a notification.
// Whether now is such a moment is the ladder's call — see attention.test.ts.
test("nothing surfaces until the ladder says it may", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "what did you eat?" }, now);
  assert.equal(queue.take(false, now), null);
  assert.equal(queue.take(true, now)?.text, "what did you eat?");
});

test("when allowed, the oldest one goes first", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "stretch?" }, now);
  assert.equal(queue.take(true, now)?.text, "stretch?");
});

test("it asks one thing at a time", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "first" }, now);
  queue.add({ text: "second" }, now);

  assert.equal(queue.take(true, now)?.text, "first");
  assert.equal(queue.take(true, now)?.text, "second", "a queue, not a pile");
  assert.equal(queue.take(true, now), null);
});

// You were away for six hours; asking what you had for lunch is now noise.
test("a stale nudge is dropped rather than asked late", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "what did you eat?", expiresInMs: 60_000 }, now);
  assert.equal(queue.take(true, now + 61_000), null);
  assert.equal(queue.size, 0);
});

test("something with no expiry waits as long as it takes", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "deploy finished" }, now);
  assert.equal(queue.take(true, now + 86_400_000)?.text, "deploy finished");
});

test("it holds everything back when not allowed", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "stretch?" }, now);
  assert.equal(queue.take(false, now), null);
  assert.equal(queue.take(true, now)?.text, "stretch?");
});

test("where the answer goes is carried with it", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "what did you eat?", replyTo: "~/bin/log-food" }, now);
  assert.equal(queue.take(true, now)?.replyTo, "~/bin/log-food");
});

test("an empty queue is quiet, not an error", () => {
  assert.equal(new NudgeQueue().take(true, now), null);
});
