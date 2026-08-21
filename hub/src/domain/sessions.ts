import { basename } from "node:path";
import type { Event, Terminal } from "./event.ts";

export type Status = "running" | "blocked" | "done" | "failed";

export type Session = {
  id: string;
  cwd: string;
  /// The worktree name for an agent — how you actually think about which is which — or
  /// whatever a generic source called itself.
  label: string;
  status: Status;
  since: number;
  /// Remembered from whichever event carried it — later events may not.
  terminal?: Terminal;
};

/** How long a finished session keeps showing before it stops being interesting. */
export const DONE_TTL_MS = 20_000;

/**
 * `failed` comes from Claude Code's StopFailure hook, which fires when a turn ends on
 * an API error. A *tool* failing is not a failed session — a red test suite is routine
 * agent work, and calling it failure would be the creature lying.
 */
export class Sessions {
  private byId = new Map<string, Session>();

  apply(e: Event): void {
    if (e.type === "ended") {
      this.byId.delete(e.sessionId);
      return;
    }

    const status: Status =
      e.type === "blocked"
        ? "blocked"
        : e.type === "failed"
          ? "failed"
          : e.type === "finished"
            ? "done"
            : "running";

    const existing = this.byId.get(e.sessionId);
    this.byId.set(e.sessionId, {
      id: e.sessionId,
      cwd: e.cwd || existing?.cwd || "",
      label: e.label ?? existing?.label ?? basename(e.cwd || "") ?? e.sessionId.slice(0, 6),
      status,
      // `since` tracks when this status began, so a session that stays blocked
      // keeps its original timestamp and we can tell how long you've been holding it up.
      since: existing?.status === status ? existing.since : e.ts,
      terminal: e.terminal ?? existing?.terminal,
    });
  }

  /** Drops finished sessions once they've had their moment. */
  prune(now = Date.now()): void {
    for (const [id, s] of this.byId) {
      const transient = s.status === "done" || s.status === "failed";
      if (transient && now - s.since > DONE_TTL_MS) this.byId.delete(id);
    }
  }

  find(id: string): Session | undefined {
    return this.byId.get(id);
  }

  list(): Session[] {
    return [...this.byId.values()].sort((a, b) => a.since - b.since);
  }
}
