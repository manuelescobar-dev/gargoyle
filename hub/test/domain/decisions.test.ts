import assert from "node:assert/strict";
import { test } from "node:test";
import { PendingDecisions } from "../../src/domain/decisions.ts";

test("an answered request resolves with the decision", async () => {
  const pending = new PendingDecisions();
  const asked = pending.ask("r1", 1000);
  pending.answer("r1", "allow");
  assert.equal(await asked, "allow");
});

test("deny comes back as deny", async () => {
  const pending = new PendingDecisions();
  const asked = pending.ask("r1", 1000);
  pending.answer("r1", "deny");
  assert.equal(await asked, "deny");
});

// The one that matters. If nobody clicks, the agent must fall through to its normal
// terminal prompt — never sit blocked because a creature was on screen.
test("an unanswered request gives up and defers", async () => {
  const pending = new PendingDecisions();
  assert.equal(await pending.ask("r1", 10), null, "null means: behave as if we weren't here");
});

test("a resolved request stops being tracked", async () => {
  const pending = new PendingDecisions();
  const asked = pending.ask("r1", 1000);
  pending.answer("r1", "allow");
  await asked;
  assert.equal(pending.size, 0, "a leak here would be a leak per tool call");
});

test("a timed-out request stops being tracked", async () => {
  const pending = new PendingDecisions();
  await pending.ask("r1", 10);
  assert.equal(pending.size, 0);
});

test("answering something nobody asked about is harmless", () => {
  const pending = new PendingDecisions();
  assert.doesNotThrow(() => pending.answer("never-existed", "allow"));
});

test("a second answer is ignored rather than throwing", async () => {
  const pending = new PendingDecisions();
  const asked = pending.ask("r1", 1000);
  pending.answer("r1", "allow");
  pending.answer("r1", "deny");
  assert.equal(await asked, "allow", "first click wins");
});

// A crashed or restarted pet must not leave every agent on the machine hanging.
test("abandoning everything releases all waiters", async () => {
  const pending = new PendingDecisions();
  const all = [pending.ask("a", 5000), pending.ask("b", 5000), pending.ask("c", 5000)];
  pending.abandonAll();
  assert.deepEqual(await Promise.all(all), [null, null, null]);
  assert.equal(pending.size, 0);
});

test("many concurrent requests stay independent", async () => {
  const pending = new PendingDecisions();
  const a = pending.ask("a", 1000);
  const b = pending.ask("b", 1000);
  pending.answer("b", "deny");
  pending.answer("a", "allow");
  assert.deepEqual(await Promise.all([a, b]), ["allow", "deny"]);
});
