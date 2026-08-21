import type { Snapshot } from "./state.ts";

/** Load at which being swamped is worth remarking on. */
const SWAMPED = 6;

const running = (s: Snapshot) => s.embers.filter((e) => e.status === "running").length;

/**
 * Whether this transition is worth the creature saying something, and about what.
 *
 * The bar is deliberately high. Gargoyle is something you *look at*, not something that
 * talks to you — so anything already visible on its body doesn't also get narrated.
 * Starting a run, gaining an agent, and needing you are all things the body shows.
 *
 * Returns a situation key; the creature's persona turns it into words, so swapping the
 * creature swaps the voice.
 */
export function situationFor(previous: Snapshot | null, next: Snapshot): string | null {
  if (!previous) return null; // arriving mid-stream is not an occasion

  if (next.state === "failed" && previous.state !== "failed") return "failed";

  // The last one finishing — a rare, genuinely companionable moment.
  if (running(previous) > 0 && running(next) === 0 && next.blocked === 0) return "idle";

  if (running(previous) < SWAMPED && running(next) >= SWAMPED) return "busy";

  return null;
}
