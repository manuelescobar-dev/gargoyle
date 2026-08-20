import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const SRC = new URL("../src/", import.meta.url).pathname;

const filesIn = (dir: string): string[] =>
  readdirSync(join(SRC, dir), { withFileTypes: true })
    .filter((e) => e.isFile() && e.name.endsWith(".ts"))
    .map((e) => join(dir, e.name));

const importsOf = (file: string): string[] =>
  [...readFileSync(join(SRC, file), "utf8").matchAll(/from\s+"([^"]+)"/g)].map((m) => m[1]);

/**
 * Dependencies point inward. The domain decides what the creature shows; it must never
 * learn that Claude Code, or HTTP, or any particular source exists.
 *
 * This is a structural test on purpose. A convention that lives only in a doc gets broken
 * by the first person in a hurry — including us.
 */
test("the domain imports nothing from sources or transport", () => {
  for (const file of filesIn("domain")) {
    for (const spec of importsOf(file)) {
      assert.ok(
        !spec.includes("sources/") && !spec.includes("server"),
        `${file} imports "${spec}" — the domain must not depend on a source or on transport`,
      );
    }
  }
});

test("every source normalizes to the domain's Event type", () => {
  const sources = filesIn("sources");
  assert.ok(sources.length > 0, "no sources found — has the folder moved?");

  for (const file of sources) {
    assert.ok(
      importsOf(file).some((s) => s.includes("domain/event")),
      `${file} does not import the domain Event type. Every source must normalize to one shape.`,
    );
  }
});
