import assert from "node:assert/strict";
import { test } from "node:test";
import {
  GARGOYLE_MARKER,
  withGargoyleHooks,
  withoutGargoyleHooks,
} from "../../src/setup/claude-hooks.ts";

const commandsFor = (s: Record<string, any>, event: string): string[] =>
  (s.hooks?.[event] ?? []).flatMap((g: any) => g.hooks.map((h: any) => h.command));

test("adds our hooks to empty settings", () => {
  const { settings, added } = withGargoyleHooks({});
  assert.ok(added.includes("Notification"));
  assert.ok(commandsFor(settings, "Notification")[0].includes(GARGOYLE_MARKER));
});

test("leaves unrelated settings completely alone", () => {
  const { settings } = withGargoyleHooks({ model: "opus", env: { FOO: "1" } });
  assert.equal((settings as any).model, "opus");
  assert.deepEqual((settings as any).env, { FOO: "1" });
});

// This is the one that matters. Clobbering someone's existing hooks would be
// unforgivable for a tool that asked to edit their config.
test("keeps hooks that were already there on the same event", () => {
  const theirs = { command: "echo mine", type: "command" };
  const { settings } = withGargoyleHooks({ hooks: { Stop: [{ hooks: [theirs] }] } });

  const commands = commandsFor(settings, "Stop");
  assert.ok(commands.includes("echo mine"), "their hook must survive");
  assert.equal(commands.length, 2, "ours is appended, not substituted");
});

// The one hook that waits on a human needs longer than the rest, and a hard stop that
// hands the question back to the terminal rather than leaving the agent blocked.
test("the permission hook waits longer, and is bounded twice over", () => {
  const settings = withGargoyleHooks({}).settings as any;
  const group = settings.hooks.PermissionRequest[0];
  const command = group.hooks[0].command as string;

  const matched = command.match(/-m (\d+)/);
  assert.ok(matched, "the permission hook should carry an explicit curl timeout");
  const curlSeconds = Number(matched[1]);
  assert.ok(curlSeconds > 5, "two seconds is shorter than a person");
  assert.ok(
    curlSeconds < group.hooks[0].timeout,
    "curl must give up before Claude Code does, so we're always the one to yield",
  );
});

test("every other hook stays fire-and-forget", () => {
  const settings = withGargoyleHooks({}).settings as any;
  for (const event of ["Stop", "SessionStart", "SessionEnd"]) {
    const hook = settings.hooks[event][0].hooks[0];
    assert.match(hook.command, /-m 2 /, `${event} must not hold up an agent`);
    assert.equal(hook.timeout, undefined);
  }
});

test("running it twice changes nothing", () => {
  const once = withGargoyleHooks({}).settings;
  const twice = withGargoyleHooks(structuredClone(once));

  assert.deepEqual(twice.settings, once);
  assert.deepEqual(twice.added, [], "nothing to add the second time");
});

// Without this, changing the hook command ships to nobody: install sees the marker,
// says "already wired", and leaves the old command in place forever.
test("an out-of-date gargoyle hook is upgraded in place", () => {
  const stale = {
    hooks: {
      Stop: [
        { hooks: [{ type: "command", command: "echo mine" }] },
        { hooks: [{ type: "command", command: "curl old-and-busted # gargoyle" }] },
      ],
    },
  };
  const { settings, upgraded } = withGargoyleHooks(stale);

  const commands = commandsFor(settings, "Stop");
  assert.ok(commands.includes("echo mine"), "still not our business");
  assert.equal(
    commands.filter((c) => c.includes(GARGOYLE_MARKER)).length,
    1,
    "replaced, not doubled",
  );
  assert.ok(!commands.some((c) => c.includes("old-and-busted")));
  assert.ok(upgraded.includes("Stop"));
});

test("an already-current install changes nothing", () => {
  const once = withGargoyleHooks({}).settings;
  const twice = withGargoyleHooks(structuredClone(once));
  assert.deepEqual(twice.added, []);
  assert.deepEqual(twice.upgraded, []);
});

test("uninstall removes only ours", () => {
  const theirs = { command: "echo mine", type: "command" };
  const installed = withGargoyleHooks({ hooks: { Stop: [{ hooks: [theirs] }] } }).settings;

  const commands = commandsFor(withoutGargoyleHooks(installed), "Stop");
  assert.deepEqual(commands, ["echo mine"]);
});

test("install then uninstall round-trips to the original", () => {
  const original = {
    model: "opus",
    hooks: { Stop: [{ hooks: [{ type: "command", command: "echo mine" }] }] },
  };
  const roundTripped = withoutGargoyleHooks(withGargoyleHooks(structuredClone(original)).settings);

  assert.deepEqual(roundTripped, original, "we must leave no trace behind");
});

test("uninstalling when nothing is installed is a no-op", () => {
  const original = { model: "opus" };
  assert.deepEqual(withoutGargoyleHooks(structuredClone(original)), original);
});
