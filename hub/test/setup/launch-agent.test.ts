import assert from "node:assert/strict";
import { test } from "node:test";
import { AGENT_LABEL, plistFor } from "../../src/setup/launch-agent.ts";

const plist = plistFor({ node: "/usr/bin/node", script: "/repo/hub/src/index.ts", logDir: "/logs" });

test("the plist names the program, the script and the label", () => {
  assert.ok(plist.includes(AGENT_LABEL));
  assert.ok(plist.includes("/usr/bin/node"));
  assert.ok(plist.includes("/repo/hub/src/index.ts"));
});

test("it starts at login and comes back if it dies", () => {
  assert.ok(plist.includes("RunAtLoad"), "the hub must outlive a reboot");
  assert.ok(plist.includes("KeepAlive"), "a crashed hub that stays dead is a creature that lies");
});

test("it captures output somewhere findable", () => {
  assert.ok(plist.includes("/logs/hub.log"));
  assert.ok(plist.includes("/logs/hub.error.log"));
});

test("paths with spaces don't break the XML", () => {
  const awkward = plistFor({
    node: "/usr/bin/node",
    script: "/Users/me/My Documents/gargoyle/hub/src/index.ts",
    logDir: "/logs",
  });
  assert.ok(awkward.includes("<string>/Users/me/My Documents/gargoyle/hub/src/index.ts</string>"));
});

test("XML special characters are escaped", () => {
  const nasty = plistFor({ node: "/n", script: "/a&b/index.ts", logDir: "/logs" });
  assert.ok(nasty.includes("/a&amp;b/index.ts"), "an unescaped & is a corrupt plist");
  assert.ok(!nasty.includes("/a&b/"));
});
