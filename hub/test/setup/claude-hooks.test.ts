import assert from "node:assert/strict";
import { test } from "node:test";
import { GARGOYLE_MARKER, withGargoyleHooks, withoutGargoyleHooks } from "../../src/setup/claude-hooks.ts";

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

test("running it twice changes nothing", () => {
  const once = withGargoyleHooks({}).settings;
  const twice = withGargoyleHooks(structuredClone(once));

  assert.deepEqual(twice.settings, once);
  assert.deepEqual(twice.added, [], "nothing to add the second time");
});

test("still idempotent after the port changes", () => {
  const once = withGargoyleHooks({}).settings as any;
  once.hooks.Notification[0].hooks[0].command = "curl localhost:9999/event # gargoyle";

  assert.deepEqual(withGargoyleHooks(once).added, [], "the marker identifies ours, not the port");
});

test("uninstall removes only ours", () => {
  const theirs = { command: "echo mine", type: "command" };
  const installed = withGargoyleHooks({ hooks: { Stop: [{ hooks: [theirs] }] } }).settings;

  const commands = commandsFor(withoutGargoyleHooks(installed), "Stop");
  assert.deepEqual(commands, ["echo mine"]);
});

test("install then uninstall round-trips to the original", () => {
  const original = { model: "opus", hooks: { Stop: [{ hooks: [{ type: "command", command: "echo mine" }] }] } };
  const roundTripped = withoutGargoyleHooks(withGargoyleHooks(structuredClone(original)).settings);

  assert.deepEqual(roundTripped, original, "we must leave no trace behind");
});

test("uninstalling when nothing is installed is a no-op", () => {
  const original = { model: "opus" };
  assert.deepEqual(withoutGargoyleHooks(structuredClone(original)), original);
});
