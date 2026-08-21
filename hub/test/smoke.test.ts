import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

/**
 * Starts the real hub and exercises the paths that only exist once everything is wired
 * together.
 *
 * This file exists because of a bug it would have caught instantly: `levelFor` was never
 * imported into index.ts, so every nudge and every line the creature spoke threw and was
 * swallowed by a handler's catch. Nothing failed, nothing logged, and 150 passing unit
 * tests had nothing to say about it — because index.ts is the one file none of them touch.
 *
 * A composition root with no test is a place where wiring mistakes are invisible.
 */
// A port each: these tests run in parallel, and two hubs fighting over one port means the
// second exits on EADDRINUSE and never reports listening.
let nextPort = 7400 + (process.pid % 100) * 10;

async function startHub() {
  const port = nextPort++;
  const entry = fileURLToPath(new URL("../src/index.ts", import.meta.url));
  const hub = spawn(process.execPath, [entry], {
    env: { ...process.env, GARGOYLE_PORT: String(port), GARGOYLE_CONFIG: "/nonexistent" },
    stdio: ["ignore", "pipe", "pipe"],
  });

  const said: string[] = [];
  hub.stdout.on("data", (chunk) => said.push(String(chunk)));
  hub.stderr.on("data", (chunk) => said.push(String(chunk)));

  // Wait for it to say it's listening, rather than guessing at a delay.
  const deadline = Date.now() + 8000;
  while (Date.now() < deadline && !said.join("").includes("listening")) {
    await new Promise((r) => setTimeout(r, 50));
  }

  return {
    port,
    said,
    stop: async () => {
      hub.kill();
      await once(hub, "exit");
    },
  };
}

const post = (port: number, path: string, body: unknown) =>
  fetch(`http://127.0.0.1:${port}${path}`, { method: "POST", body: JSON.stringify(body) }).then(
    (r) => r.text(),
  );

test("the wired-up hub survives every path without throwing", async () => {
  const hub = await startHub();
  assert.ok(hub.said.join("").includes("listening"), `hub never started: ${hub.said.join("")}`);

  // Each of these runs a handler that unit tests never reach through index.ts.
  const p = hub.port;
  await post(p, "/event", { hook_event_name: "SessionStart", session_id: "s1", cwd: "/w/api" });
  await post(p, "/event", { id: "ci", label: "build", status: "running" });
  await post(p, "/nudge", { text: "still there?" });
  await post(p, "/action", { id: "opened" }); // ← the one that was silently throwing
  await post(p, "/action", { id: "focus:s1" });
  await post(p, "/context", { currentSession: "abc", undisturbed: false });
  await post(p, "/decision", { id: "r1", decision: "allow" });
  await post(p, "/reply", { id: "n1", text: "yes" });
  await new Promise((r) => setTimeout(r, 300));

  const output = hub.said.join("");
  assert.ok(!output.includes("failed:"), `a handler threw: ${output}`);
  assert.ok(!output.includes("is not defined"), `something wasn't imported: ${output}`);

  await hub.stop();
});

test("a nudge posted then glanced at actually reaches a listener", async () => {
  const hub = await startHub();
  const socket = new WebSocket(`ws://127.0.0.1:${hub.port}/socket`);
  const bubbles: Array<Record<string, unknown>> = [];

  socket.onmessage = (event) => {
    const message = JSON.parse(String(event.data));
    if (message.t === "bubble") bubbles.push(message);
  };
  await new Promise((r) => (socket.onopen = r));

  await post(hub.port, "/nudge", { text: "how did that go?", reply_to: "true" });
  assert.deepEqual(bubbles, [], "a nudge must wait for a moment you're already looking");

  await post(hub.port, "/action", { id: "opened" });
  await new Promise((r) => setTimeout(r, 400));

  assert.equal(bubbles.length, 1, "opening the popover is a glance, and should surface it");
  assert.equal(bubbles[0].text, "how did that go?");

  socket.close();
  await hub.stop();
});
