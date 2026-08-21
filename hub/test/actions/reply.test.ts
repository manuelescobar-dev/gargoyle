import assert from "node:assert/strict";
import { readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { deliverReply } from "../../src/actions/reply.ts";

const settle = () => new Promise((r) => setTimeout(r, 300));

test("the answer arrives on stdin, where nothing needs escaping", async () => {
  const out = join(tmpdir(), `gargoyle-reply-${process.pid}.txt`);
  deliverReply(`cat > ${out}`, "chicken and rice");
  await settle();

  assert.equal(readFileSync(out, "utf8"), "chicken and rice");
  rmSync(out, { force: true });
});

// The text is whatever you typed at a creature. It must never become part of a command.
test("shell metacharacters in an answer stay data", async () => {
  const out = join(tmpdir(), `gargoyle-reply-hostile-${process.pid}.txt`);
  deliverReply(`cat > ${out}`, '"; rm -rf ~; echo "');
  await settle();

  assert.equal(
    readFileSync(out, "utf8"),
    '"; rm -rf ~; echo "',
    "delivered verbatim, run as nothing",
  );
  rmSync(out, { force: true });
});

// A command that exits before reading stdin closes the pipe. The write then lands as an
// unhandled EPIPE, which took the whole hub down until CI on Linux caught it.
test("a command that exits before reading stdin doesn't take the hub down", async () => {
  assert.doesNotThrow(() => deliverReply("exit 1", "anything"));
  await settle();
});

test("a command that exits instantly while we write a lot doesn't either", async () => {
  assert.doesNotThrow(() => deliverReply("exit 0", "x".repeat(200_000)));
  await settle();
});

test("a command that doesn't exist doesn't take the hub down", async () => {
  assert.doesNotThrow(() => deliverReply("definitely-not-a-real-command-xyz", "anything"));
  await settle();
});
