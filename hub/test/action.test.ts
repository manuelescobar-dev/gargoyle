import assert from "node:assert/strict";
import { test } from "node:test";
import { createHub } from "../src/server.ts";

const listen = async () => {
  const seen: string[] = [];
  const { server } = createHub({ onAction: (id) => seen.push(id) });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  const port = (server.address() as { port: number }).port;
  return {
    seen,
    port,
    close: () => {
      server.closeAllConnections();
      server.close();
    },
  };
};

const post = (port: number, body: string) =>
  fetch(`http://127.0.0.1:${port}/action`, { method: "POST", body });

test("a chosen menu item reaches the hub", async () => {
  const hub = await listen();
  await post(hub.port, JSON.stringify({ id: "focus:s3" }));
  assert.deepEqual(hub.seen, ["focus:s3"]);
  hub.close();
});

// The pet is on the other side of a socket. A malformed action must not take down the
// process every agent on the machine is reporting to.
test("a malformed action is survivable", async () => {
  const hub = await listen();
  for (const body of ["not json", "{}", '{"id":42}', ""]) {
    const res = await post(hub.port, body);
    assert.equal(res.status, 204, `${body} should be accepted quietly`);
  }
  assert.deepEqual(hub.seen, [], "nothing valid was sent");
  hub.close();
});
