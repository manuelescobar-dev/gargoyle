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
test("nothing surfaces until you're already looking", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "what did you eat?" }, now);
  assert.equal(queue.takeFor("nothing-happened", now), null);
  assert.equal(queue.takeFor("glance", now)?.text, "what did you eat?");
});

test("a run finishing counts as a glance — you looked over", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "stretch?" }, now);
  assert.equal(queue.takeFor("finished", now)?.text, "stretch?");
});

test("it asks one thing at a time", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "first" }, now);
  queue.add({ text: "second" }, now);

  assert.equal(queue.takeFor("glance", now)?.text, "first");
  assert.equal(queue.takeFor("glance", now)?.text, "second", "a queue, not a pile");
  assert.equal(queue.takeFor("glance", now), null);
});

// You were away for six hours; asking what you had for lunch is now noise.
test("a stale nudge is dropped rather than asked late", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "what did you eat?", expiresInMs: 60_000 }, now);
  assert.equal(queue.takeFor("glance", now + 61_000), null);
  assert.equal(queue.size, 0);
});

test("something with no expiry waits as long as it takes", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "deploy finished" }, now);
  assert.equal(queue.takeFor("glance", now + 86_400_000)?.text, "deploy finished");
});

// Never interrupt into a blocked agent — you're mid-decision about something that matters.
test("it holds off while something needs you", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "stretch?" }, now);
  assert.equal(queue.takeFor("glance", now, { busy: true }), null);
  assert.equal(queue.takeFor("glance", now, { busy: false })?.text, "stretch?");
});

test("where the answer goes is carried with it", () => {
  const queue = new NudgeQueue();
  queue.add({ text: "what did you eat?", replyTo: "~/bin/log-food" }, now);
  assert.equal(queue.takeFor("glance", now)?.replyTo, "~/bin/log-food");
});

test("an empty queue is quiet, not an error", () => {
  assert.equal(new NudgeQueue().takeFor("glance", now), null);
});
