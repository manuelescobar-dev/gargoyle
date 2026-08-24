import assert from "node:assert/strict";
import { test } from "node:test";
import { createHub } from "../src/server.ts";

const start = async (onSay?: (text: string) => void) => {
  const { server } = createHub({ onSay });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  return {
    port: (server.address() as { port: number }).port,
    close: () => {
      server.closeAllConnections();
      server.close();
    },
  };
};

// Holding an HTTP request open for a minute is how the old version failed: silently, with
// no way to tell a slow agent from a broken one. Saying something should return at once
// and the answer should arrive the way every other bubble does.
test("saying something returns immediately, however slow the answer is", async () => {
  const hub = await start(() => {});
  const began = Date.now();

  const res = await fetch(`http://127.0.0.1:${hub.port}/say`, {
    method: "POST",
    body: JSON.stringify({ text: "how is it going?" }),
  });
  await res.text();

  assert.equal(res.status, 202, "accepted, not answered");
  assert.ok(Date.now() - began < 500, "the pet must not wait on an agent turn");
  hub.close();
});

test("what you said reaches the handler", async () => {
  const heard: string[] = [];
  const hub = await start((text) => heard.push(text));

  await (
    await fetch(`http://127.0.0.1:${hub.port}/say`, {
      method: "POST",
      body: JSON.stringify({ text: "  hello there  " }),
    })
  ).text();

  assert.deepEqual(heard, ["hello there"], "trimmed");
  hub.close();
});

test("saying nothing does nothing", async () => {
  const heard: string[] = [];
  const hub = await start((text) => heard.push(text));

  for (const body of ['{"text":"   "}', "{}", "junk", '{"text":42}']) {
    const res = await fetch(`http://127.0.0.1:${hub.port}/say`, { method: "POST", body });
    await res.text();
  }

  assert.deepEqual(heard, []);
  hub.close();
});
