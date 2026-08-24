import assert from "node:assert/strict";
import { test } from "node:test";
import { ask } from "../../src/actions/ask.ts";

test("what it says back is what the command printed", async () => {
  assert.equal(await ask("cat", "hello there"), "hello there");
});

// The text is whatever you said to a creature. It must never become part of a command.
test("what you say can't become a command", async () => {
  const hostile = '"; touch /tmp/gargoyle-should-not-exist; echo "';
  assert.equal(await ask("cat", hostile), hostile, "delivered verbatim, run as nothing");
});

test("a command that says nothing produces nothing to show", async () => {
  assert.equal(await ask("true", "anything"), null);
});

test("a command that fails doesn't take the hub down", async () => {
  assert.equal(await ask("exit 1", "anything"), null);
});

test("a command that doesn't exist doesn't either", async () => {
  assert.equal(await ask("definitely-not-a-command-xyz", "anything"), null);
});

// A creature that goes quiet for a minute waiting on a slow agent is worse than one that
// shrugs. The bubble has to come back while you're still looking at it.
test("a slow command is given up on", async () => {
  const began = Date.now();
  assert.equal(await ask("sleep 30", "anything", 500), null);
  assert.ok(Date.now() - began < 3000, "it should stop waiting quickly");
});

test("an essay is trimmed to something a bubble can hold", async () => {
  const long = await ask("printf 'x%.0s' $(seq 1 5000)", "anything");
  assert.ok(long !== null && long.length <= 400, `got ${long?.length} characters`);
});

test("surrounding whitespace is dropped", async () => {
  assert.equal(await ask("printf '\\n  spaced  \\n'", "x"), "spaced");
});
