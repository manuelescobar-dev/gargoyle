import { levelFor, type Level, type Surroundings } from "./attention.ts";
import type { Session } from "./sessions.ts";

/**
 * The nine states a creature can be in. `unknown` never originates here — the pet
 * enters it on its own when the socket drops, because by then the hub is what's missing.
 */
export type CreatureState =
  | "asleep"
  | "idle"
  | "working"
  | "needs-you"
  | "done"
  | "failed"
  | "speaking"
  | "listening"
  | "unknown";

export type Ember = {
  id: string;
  label: string;
  status: Session["status"];
  /// When this status began — an absolute time, so an unchanged snapshot stays unchanged
  /// and doesn't put a frame on the wire every second.
  since: number;
  /// Whether there's somewhere to jump to. A CI job has no terminal.
  focusable: boolean;
};

export type Snapshot = {
  state: CreatureState;
  embers: Ember[];
  mood: number; // 0 calm → 1 frazzled
  blocked: number;
  /// How loudly this may be shown — the interruption ladder, on the wire at last.
  attention: Level;
};

/** Load at which the creature reads as fully overwhelmed. */
const FRAZZLED_AT = 6;

/**
 * The whole visual state, derived fresh every time. The pet renders exactly this and
 * keeps nothing, which is what makes it structurally unable to accumulate logic.
 */
export function snapshot(
  sessions: Session[],
  surroundings: Surroundings = { moment: "", busy: false, undisturbed: false },
  now = Date.now(),
): Snapshot {
  const embers: Ember[] = sessions.map((s) => ({
    id: s.id,
    label: s.label,
    status: s.status,
    since: s.since,
    focusable: s.terminal !== undefined,
  }));

  const blocked = embers.filter((e) => e.status === "blocked").length;
  const running = embers.filter((e) => e.status === "running").length;
  const done = embers.filter((e) => e.status === "done").length;
  const failed = embers.filter((e) => e.status === "failed").length;

  // Order matters: anything blocked outranks everything, because it's the only
  // state where the cost of you not noticing keeps growing.
  let state: CreatureState = "idle";
  if (blocked > 0) state = "needs-you";
  else if (running > 0) state = "working";
  else if (failed > 0) state = "failed";
  else if (done > 0) state = "done";

  // The longest wait decides how loud this is allowed to get.
  const oldestBlocked = embers
    .filter((e) => e.status === "blocked")
    .reduce((oldest, e) => Math.min(oldest, e.since), now);

  return {
    state,
    embers,
    mood: Math.min(1, embers.length / FRAZZLED_AT),
    blocked,
    attention:
      blocked > 0
        ? levelFor({ kind: "blocked", waitedMs: now - oldestBlocked }, surroundings)
        : levelFor({ kind: "state" }, surroundings),
  };
}
