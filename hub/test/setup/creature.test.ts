import assert from "node:assert/strict";
import { test } from "node:test";
import { availableCreatures, chosenCreature, withCreature } from "../../src/setup/creature.ts";

const available = ["dinosaur", "octopus", "slime"];

test("a configured creature is read back", () => {
  assert.equal(chosenCreature({ creature: "dinosaur" }), "dinosaur");
});

// Most people never change it, and the default has to be a creature that exists.
test("nothing configured means the default", () => {
  assert.equal(chosenCreature({}), "octopus");
  assert.equal(chosenCreature(undefined), "octopus");
  assert.equal(chosenCreature({ creature: 42 }), "octopus");
  assert.equal(chosenCreature("nonsense"), "octopus");
});

test("choosing one keeps everything else in the config", () => {
  const before = { ask: "openclaw agent", sources: [{ run: "x", every: "5m" }] };
  const after = withCreature(before, "slime", available);

  assert.equal(after.creature, "slime");
  assert.equal(after.ask, "openclaw agent");
  assert.deepEqual(after.sources, before.sources);
});

test("choosing one twice is the same as choosing it once", () => {
  const once = withCreature({}, "slime", available);
  assert.deepEqual(withCreature(once, "slime", available), once);
});

// The config is a file people edit by hand. A creature that isn't there would leave them
// with whatever the pet falls back to, and no idea why.
test("it doesn't write a creature that doesn't exist", () => {
  assert.throws(() => withCreature({}, "wyvern", available), /wyvern/);
});

// The list comes from the directory rather than an array in code, so it can't drift from
// what actually ships. If this fails, a creature was added or removed without its folder.
test("the creatures that ship are the ones with folders", () => {
  const found = availableCreatures();
  assert.ok(found.includes("octopus"), "the default must always exist");
  assert.ok(found.length >= 2, `only found: ${found.join(", ")}`);
});
