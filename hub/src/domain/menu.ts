import type { Snapshot } from "./state.ts";

/**
 * What you can do right now, ordered by what you most likely want.
 *
 * Built here rather than in the pet: which agent is worth jumping to is semantics, and
 * keeping that out of the surface is what makes a second surface cheap.
 */
export function menuFor(snapshot: Snapshot): Array<{ id: string; label: string }> {
  // Blocked first — it's the only thing whose cost grows while you don't look at it.
  const ordered = [...snapshot.embers].sort((a, b) => {
    if (a.status === b.status) return 0;
    return a.status === "blocked" ? -1 : 1;
  });

  return ordered.map((ember) => ({
    id: `focus:${ember.id}`,
    label: ember.status === "blocked" ? `Jump to ${ember.label} — waiting` : `Jump to ${ember.label}`,
  }));
}
