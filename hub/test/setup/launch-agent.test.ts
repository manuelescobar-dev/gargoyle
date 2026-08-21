import assert from "node:assert/strict";
import { test } from "node:test";
import { AGENT_LABEL, PET_LABEL, petPlistFor, plistFor } from "../../src/setup/launch-agent.ts";

const plist = plistFor({
  node: "/usr/bin/node",
  script: "/repo/hub/src/index.ts",
  logDir: "/logs",
});

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

// The creature is the half people actually notice is missing after a reboot.
test("the pet gets its own agent, launching the bundle", () => {
  const plist = petPlistFor({ app: "/Users/me/Applications/Gargoyle.app", logDir: "/logs" });
  assert.ok(plist.includes(PET_LABEL));
  assert.ok(plist.includes("/Users/me/Applications/Gargoyle.app/Contents/MacOS/Gargoyle"));
  assert.ok(plist.includes("RunAtLoad"), "always on screen has to survive a restart");
  assert.ok(plist.includes("/logs/pet.log"), "its own log, not the hub's");
});

test("the two agents don't collide", () => {
  assert.notEqual(AGENT_LABEL, PET_LABEL);
  const hub = plistFor({ node: "/n", script: "/s", logDir: "/logs" });
  assert.ok(!hub.includes(PET_LABEL));
});

// launchd hands an agent a minimal PATH with no nvm, no Homebrew, no ~/bin — so a
// `reply_to: "openclaw agent ..."` dies with "command not found" and the user has no idea why.
test("the hub inherits the PATH you installed with", () => {
  const plist = plistFor({
    node: "/n",
    script: "/s",
    logDir: "/logs",
    path: "/opt/homebrew/bin:/usr/bin",
  });
  assert.ok(plist.includes("EnvironmentVariables"));
  assert.ok(plist.includes("/opt/homebrew/bin:/usr/bin"));
});

test("no PATH given means no PATH key, rather than an empty one", () => {
  const plist = plistFor({ node: "/n", script: "/s", logDir: "/logs" });
  assert.ok(!plist.includes("EnvironmentVariables"), "an empty PATH would be worse than none");
});

// The Quit button was unwinnable: KeepAlive:true relaunched the creature the instant it
// exited, so quitting looked like the app ignoring you. Found by using it, not by testing it.
test("quitting the creature sticks", () => {
  const plist = petPlistFor({ app: "/Applications/Gargoyle.app", logDir: "/logs" });
  assert.match(plist, /<key>SuccessfulExit<\/key>\s*<false\/>/, "only restart on a crash");
  assert.ok(
    !/<key>KeepAlive<\/key>\s*<true\/>/.test(plist),
    "an unconditional KeepAlive is a Quit button that cannot win",
  );
});

test("but a crashed creature still comes back", () => {
  const plist = petPlistFor({ app: "/Applications/Gargoyle.app", logDir: "/logs" });
  assert.ok(plist.includes("KeepAlive"), "quitting sticking must not mean crashing sticks too");
});

// The hub has no Quit button and a hub that stays dead is a creature that lies.
test("the hub restarts whatever happens", () => {
  const plist = plistFor({ node: "/n", script: "/s", logDir: "/logs" });
  assert.match(plist, /<key>KeepAlive<\/key>\s*<true\/>/);
});
