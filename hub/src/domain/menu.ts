import type { Snapshot } from "./state.ts";

export type Context = {
  now: number;
  /// The terminal session you're looking at right now, if the surface could tell.
  currentSession?: string;
};

/** Below a minute, a duration is noise rather than information. */
const MINUTE = 60_000;

function waitedFor(sinceMs: number, now: number): string {
  const minutes = Math.floor((now - sinceMs) / MINUTE);
  if (minutes < 1) return "";
  if (minutes < 60) return ` — waiting ${minutes}m`;
  return ` — waiting ${Math.floor(minutes / 60)}h`;
}

/**
 * What you can do right now, ordered by what you most likely want.
 *
 * Built here rather than in the pet: which agent is worth jumping to is semantics. The pet
 * contributes what it can see of your desktop as *data*, and decides nothing.
 */
export function menuFor(
  snapshot: Snapshot,
  context: Context,
): Array<{ id: string; label: string }> {
  const rank = (ember: Snapshot["embers"][0]): [number, number] => {
    // Blocked first — it's the only state whose cost grows while you don't look at it.
    // Within that, longest wait wins, because that's the one you've been failing to notice.
    if (ember.status === "blocked") return [0, ember.since];

    // You're already in this tab, so jumping to it is the least useful row here. Doesn't
    // apply to a blocked one: being in the tab doesn't answer the question.
    if (ember.id === context.currentSession) return [2, ember.since];

    return [1, -ember.since]; // most recently active first
  };

  return (
    [...snapshot.embers]
      // A CI job or a Shortcut has no terminal, so offering to jump there would be a row
      // that does nothing — which is the same failure as a stale action, just quieter.
      .filter((ember) => ember.focusable)
      .sort((a, b) => {
        const [groupA, tieA] = rank(a);
        const [groupB, tieB] = rank(b);
        return groupA !== groupB ? groupA - groupB : tieA - tieB;
      })
      .map((ember) => ({
        id: `focus:${ember.id}`,
        label:
          ember.status === "blocked"
            ? `Jump to ${ember.label}${waitedFor(ember.since, context.now) || " — waiting"}`
            : `Jump to ${ember.label}`,
      }))
  );
}
