import { existsSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const DEFAULT_CREATURE = "octopus";

/**
 * Which creatures exist, read from the `creatures/` directory rather than a list in code.
 *
 * A creature exists if its folder does, so this can't drift from reality the way a
 * hardcoded array would.
 */
export function availableCreatures(root = repoRoot()): string[] {
  const dir = join(root, "creatures");
  if (!existsSync(dir)) return [DEFAULT_CREATURE];

  const found = readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && existsSync(join(dir, entry.name, "persona.md")))
    .map((entry) => entry.name)
    .sort();

  return found.length ? found : [DEFAULT_CREATURE];
}

export function chosenCreature(config: unknown): string {
  const named = (config as { creature?: unknown })?.creature;
  return typeof named === "string" && named.trim() ? named : DEFAULT_CREATURE;
}

/** Sets the creature, leaving the rest of your config alone. */
export function withCreature(
  config: Record<string, unknown>,
  creature: string,
  available = availableCreatures(),
): Record<string, unknown> {
  if (!available.includes(creature)) {
    // Writing one that doesn't exist would leave you with whatever the pet falls back to
    // and no idea why.
    throw new Error(`no creature called "${creature}" — try: ${available.join(", ")}`);
  }
  return { ...config, creature };
}

/// `hub/src/setup/creature.ts` → the repo. Four levels, and getting it wrong silently
/// leaves you with a list of one.
function repoRoot(): string {
  return dirname(dirname(dirname(dirname(fileURLToPath(import.meta.url)))));
}
