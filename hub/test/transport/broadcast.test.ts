import assert from "node:assert/strict";
import { test } from "node:test";
import type { Snapshot } from "../../src/domain/state.ts";
import { Broadcaster } from "../../src/transport/broadcast.ts";

const snap = (state: Snapshot["state"], blocked = 0): Snapshot => ({
  state,
  embers: [],
  mood: 0,
  blocked,
});

const recorder = () => {
  const sent: string[] = [];
  return { sent, send: (payload: string) => sent.push(payload) };
};

test("the first snapshot is always sent", () => {
  const r = recorder();
  new Broadcaster(r.send).publish(snap("idle"));
  assert.equal(r.sent.length, 1);
});

// An idle machine must produce no traffic at all — "it costs nothing when it's
// doing nothing" applies to the wire as much as to the render loop.
test("an unchanged snapshot sends nothing", () => {
  const r = recorder();
  const b = new Broadcaster(r.send);
  b.publish(snap("idle"));
  b.publish(snap("idle"));
  b.publish(snap("idle"));
  assert.equal(r.sent.length, 1, "only the change goes on the wire");
});

test("a changed snapshot sends again", () => {
  const r = recorder();
  const b = new Broadcaster(r.send);
  b.publish(snap("idle"));
  b.publish(snap("needs-you", 1));
  assert.equal(r.sent.length, 2);
});

test("it sends the whole state, never a diff", () => {
  const r = recorder();
  const b = new Broadcaster(r.send);
  b.publish(snap("working"));
  b.publish(snap("needs-you", 1));

  const message = JSON.parse(r.sent[1]);
  assert.equal(message.t, "state");
  assert.equal(message.state, "needs-you");
  assert.ok(
    "embers" in message && "mood" in message && "blocked" in message,
    "a pet that receives partial state would have to remember the rest",
  );
});

test("a newly connected pet gets the current state immediately", () => {
  const b = new Broadcaster(() => {});
  b.publish(snap("needs-you", 2));

  const late = recorder();
  b.greet(late.send);
  assert.equal(JSON.parse(late.sent[0]).blocked, 2, "it must not wait for the next change");
});

test("greeting before anything has happened still says something", () => {
  const late = recorder();
  new Broadcaster(() => {}).greet(late.send);
  assert.equal(JSON.parse(late.sent[0]).state, "idle");
});
