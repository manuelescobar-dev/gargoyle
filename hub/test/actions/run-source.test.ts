import assert from "node:assert/strict";
import { test } from "node:test";
import { runSource } from "../../src/actions/run-source.ts";

test("each line of output becomes something the hub already understands", async () => {
  const out = await runSource(
    `printf '{"id":"ci","label":"build","status":"running"}\\n{"text":"deploy finished"}\\n'`,
  );
  assert.equal(out.embers.length, 1);
  assert.equal(out.embers[0].id, "ci");
  assert.equal(out.nudges.length, 1);
  assert.equal(out.nudges[0].text, "deploy finished");
});

test("a source with nothing to say says nothing", async () => {
  assert.deepEqual(await runSource("true"), { embers: [], nudges: [], problem: null });
});

// Sources are shell scripts people wrote in a hurry. None of these may take the hub down.
test("junk lines are skipped, good ones still land", async () => {
  const out = await runSource(`printf 'not json\\n{"id":"ok","status":"done"}\\n\\n<html>\\n'`);
  assert.deepEqual(out.embers.map((e) => e.id), ["ok"]);
});

test("a failing command is reported, not thrown", async () => {
  const out = await runSource("exit 3");
  assert.match(out.problem ?? "", /exit|fail/i);
});

test("a command that doesn't exist is reported, not thrown", async () => {
  const out = await runSource("definitely-not-a-command-xyz");
  assert.notEqual(out.problem, null);
});

// A source that hangs must not wedge the schedule behind it forever.
test("a hanging command is cut off", async () => {
  const began = Date.now();
  const out = await runSource("sleep 30", 400);
  assert.ok(Date.now() - began < 3000, "should give up quickly");
  assert.notEqual(out.problem, null);
});

test("a torrent of output is truncated rather than swallowing memory", async () => {
  const out = await runSource(`for i in $(seq 1 5000); do echo '{"id":"x'$i'","status":"done"}'; done`);
  assert.ok(out.embers.length <= 100, `got ${out.embers.length} — a source shouldn't be able to flood the creature`);
});
