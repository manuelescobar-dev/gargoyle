import assert from "node:assert/strict";
import { test } from "node:test";
import { createHub } from "../src/server.ts";

const start = async (
  onPermissionRequest?: Parameters<typeof createHub>[0]["onPermissionRequest"],
) => {
  const decisions: Array<[string, string]> = [];
  const { server } = createHub({
    onPermissionRequest,
    onDecision: (id, d) => decisions.push([id, d]),
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  return {
    decisions,
    port: (server.address() as { port: number }).port,
    close: () => {
      server.closeAllConnections();
      server.close();
    },
  };
};

const permissionRequest = (port: number) =>
  fetch(`http://127.0.0.1:${port}/event`, {
    method: "POST",
    body: JSON.stringify({
      hook_event_name: "PermissionRequest",
      session_id: "s1",
      cwd: "/w/api",
      tool_name: "Write",
      tool_input: { file_path: "src/auth/session.ts" },
    }),
  });

// THE safety property. Claude Code treats an empty response as "no opinion" and falls
// back to its normal terminal prompt. Anything that leaves an agent blocked because a
// creature was on screen is a worse failure than not shipping the feature.
test("no answer means no opinion, and the agent carries on", async () => {
  const hub = await start(async () => null);
  const res = await permissionRequest(hub.port);
  assert.equal(res.status, 204);
  assert.equal(await res.text(), "");
  hub.close();
});

test("with nobody watching, it answers immediately rather than stalling", async () => {
  const hub = await start(async () => null);
  const began = Date.now();
  await (await permissionRequest(hub.port)).text();
  assert.ok(Date.now() - began < 500, "a tool call must not wait out a timeout for nobody");
  hub.close();
});

test("an approval comes back in the shape Claude Code reads", async () => {
  const hub = await start(async () => JSON.stringify({ decision: "allow", reason: "ok" }));
  const res = await permissionRequest(hub.port);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { decision: "allow", reason: "ok" });
  hub.close();
});

// If asking throws, the agent must still proceed. A crash here would block every tool
// call on the machine.
test("a handler that throws still lets the agent through", async () => {
  const hub = await start(async () => {
    throw new Error("boom");
  });
  const res = await permissionRequest(hub.port);
  assert.equal(res.status, 204);
  await res.text();
  hub.close();
});

test("only permission requests block — other events return at once", async () => {
  let asked = 0;
  const hub = await start(async () => {
    asked++;
    return null;
  });

  await (
    await fetch(`http://127.0.0.1:${hub.port}/event`, {
      method: "POST",
      body: JSON.stringify({ hook_event_name: "Stop", session_id: "s1", cwd: "/w/api" }),
    })
  ).text();
  assert.equal(asked, 0, "a finished run has nothing to decide");
  hub.close();
});

test("the pet's decision reaches the hub", async () => {
  const hub = await start();
  await (
    await fetch(`http://127.0.0.1:${hub.port}/decision`, {
      method: "POST",
      body: JSON.stringify({ id: "r1", decision: "allow" }),
    })
  ).text();
  assert.deepEqual(hub.decisions, [["r1", "allow"]]);
  hub.close();
});

test("a nonsense decision is ignored rather than acted on", async () => {
  const hub = await start();
  for (const body of ['{"id":"r1","decision":"maybe"}', '{"id":1,"decision":"allow"}', "junk"]) {
    const res = await fetch(`http://127.0.0.1:${hub.port}/decision`, { method: "POST", body });
    assert.equal(res.status, 204);
    await res.text();
  }
  assert.deepEqual(hub.decisions, []);
  hub.close();
});
