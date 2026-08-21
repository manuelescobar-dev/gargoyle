/**
 * The interruption ladder, as one function.
 *
 * ```
 * silent  →  badge  →  bubble  →  notify
 * ```
 *
 * Everything that wants your attention passes through here. It was prose in the
 * principles and scattered conditions across the code, which is the thing CLAUDE.md warns
 * about: if it scatters you can never tune the noise, and noise is what kills this.
 *
 * `sound` is deliberately absent. "Almost never" has so far meant never.
 */
export type Level = "silent" | "badge" | "bubble" | "notify";

export type Want =
  /// The creature's body changed. Its body is the display, so this is never louder.
  | { kind: "state" }
  /// An agent is waiting on you.
  | { kind: "blocked"; waitedMs: number }
  /// The creature has something to say in its own voice.
  | { kind: "voice"; situation: string }
  /// A source wants to ask you something.
  | { kind: "nudge" };

export type Surroundings = {
  /// A moment you're already looking: `glance`, `finished`, `returned`, `clicked`.
  moment: string;
  /// Something is blocked. That attention is already spoken for.
  busy: boolean;
  /// Fullscreen, presenting, watching something. The closest thing to Focus we can read
  /// without asking for Full Disk Access.
  undisturbed: boolean;
};

const GLANCES = new Set(["glance", "finished", "returned", "clicked"]);

/**
 * Long enough that the waving arm has plainly not worked. Escalating sooner would just be
 * shouting the same thing twice.
 */
const IGNORED_TOO_LONG_MS = 10 * 60_000;

export function levelFor(want: Want, surroundings: Surroundings): Level {
  // The body is the display. Nothing about it needs announcing.
  if (want.kind === "state") return "silent";

  if (want.kind === "blocked") {
    if (surroundings.undisturbed) return "badge";
    return want.waitedMs >= IGNORED_TOO_LONG_MS ? "notify" : "badge";
  }

  // Everything conversational needs all three: you're looking, nothing is waiting on you,
  // and you're not in the middle of something.
  if (!GLANCES.has(surroundings.moment)) return "silent";
  if (surroundings.busy || surroundings.undisturbed) return "silent";
  return "bubble";
}
