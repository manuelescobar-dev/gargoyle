import assert from "node:assert/strict";
import { test } from "node:test";
import { readSources } from "../../src/setup/sources.ts";

test("a source reads the way you'd write it", () => {
  const { sources } = readSources({ sources: [{ run: "~/bin/check-ci", every: "5m" }] });
  assert.deepEqual(sources, [{ run: "~/bin/check-ci", everyMs: 300_000, whenBusy: false }]);
});

test("a source can opt into running while you're busy", () => {
  const { sources } = readSources({ sources: [{ run: "x", every: "1m", whenBusy: true }] });
  assert.equal(sources[0].whenBusy, true);
});

// One bad line shouldn't cost you the rest of your config, and it must say so — a source
// that silently never runs is indistinguishable from one that finds nothing.
test("a broken source is skipped and named", () => {
  const { sources, problems } = readSources({
    sources: [
      { run: "good", every: "5m" },
      { run: "bad", every: "soon" },
      { every: "5m" },
      "not even an object",
    ],
  });

  assert.deepEqual(sources.map((s) => s.run), ["good"]);
  assert.equal(problems.length, 3);
  assert.ok(problems.some((p) => p.includes("soon")), "should say what it couldn't read");
});

test("no config at all is fine — most people won't have one", () => {
  assert.deepEqual(readSources(undefined), { sources: [], problems: [] });
  assert.deepEqual(readSources({}), { sources: [], problems: [] });
});

test("a config that isn't even a config doesn't throw", () => {
  assert.deepEqual(readSources("nope").sources, []);
  assert.deepEqual(readSources({ sources: "nope" }).sources, []);
});
