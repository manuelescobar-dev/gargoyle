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

export type Ember = { id: string; label: string; status: Session["status"] };

export type Snapshot = {
  state: CreatureState;
  embers: Ember[];
  mood: number; // 0 calm → 1 frazzled
  blocked: number;
};

/** Load at which the creature reads as fully overwhelmed. */
const FRAZZLED_AT = 6;

/**
 * The whole visual state, derived fresh every time. The pet renders exactly this and
 * keeps nothing, which is what makes it structurally unable to accumulate logic.
 */
export function snapshot(sessions: Session[]): Snapshot {
  const embers: Ember[] = sessions.map((s) => ({
    id: s.id,
    label: s.label,
    status: s.status,
  }));

  const blocked = embers.filter((e) => e.status === "blocked").length;
  const running = embers.filter((e) => e.status === "running").length;
  const done = embers.filter((e) => e.status === "done").length;

  // Order matters: anything blocked outranks everything, because it's the only
  // state where the cost of you not noticing keeps growing.
  let state: CreatureState = "idle";
  if (blocked > 0) state = "needs-you";
  else if (running > 0) state = "working";
  else if (done > 0) state = "done";

  return {
    state,
    embers,
    mood: Math.min(1, embers.length / FRAZZLED_AT),
    blocked,
  };
}
