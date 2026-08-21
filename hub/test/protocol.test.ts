import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { Sessions } from "../src/domain/sessions.ts";
import { snapshot } from "../src/domain/state.ts";

/**
 * The pet decodes this exact file (pet/Tests/GargoyleCoreTests/SnapshotDecodingTests.swift).
 * The hub asserts it still produces it.
 *
 * Protocol drift across two languages is the classic silent failure in this architecture —
 * the hub renames a field, the pet keeps compiling, and the creature quietly shows nothing.
 * One shared fixture makes that impossible to ship.
 */
const fixture = JSON.parse(
  readFileSync(new URL("../../protocol/fixtures/state.json", import.meta.url), "utf8"),
);

test("the hub still produces the shape the pet decodes", () => {
  const sessions = new Sessions();
  let ts = 0;
  for (const [id, cwd, type] of [
    ["s1", "/w/api-refactor", "started"],
    ["s2", "/w/gargoyle", "started"],
    ["s3", "/w/billing-fix", "blocked"],
  ] as const) {
    sessions.apply({
      source: "claude-code",
      sessionId: id,
      cwd,
      type,
      ts: ++ts,
      // Agents run in a terminal, which is what makes them jumpable.
      terminal: { app: "iTerm.app", term: `w0t0p0:${id}` },
    });
  }

  assert.deepEqual(snapshot(sessions.list()), fixture);
});
