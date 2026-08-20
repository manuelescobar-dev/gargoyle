import { basename } from "node:path";
import type { Event } from "./event.ts";

export type Status = "running" | "blocked" | "done";

export type Session = {
  id: string;
  cwd: string;
  label: string; // the worktree name — how you actually think about which agent this is
  status: Status;
  since: number;
};

/** How long a finished session keeps showing before it stops being interesting. */
export const DONE_TTL_MS = 20_000;

/**
 * NOTE: there is no "failed" status yet. Claude Code's Stop hook doesn't say whether
 * the run succeeded, so we'd be guessing. Detecting it means reading the transcript,
 * which is M1 work — better to show three honest statuses than four with one invented.
 */
export class Sessions {
  private byId = new Map<string, Session>();

  apply(e: Event): void {
    if (e.type === "ended") {
      this.byId.delete(e.sessionId);
      return;
    }

    const status: Status =
      e.type === "blocked" ? "blocked" : e.type === "finished" ? "done" : "running";

    const existing = this.byId.get(e.sessionId);
    this.byId.set(e.sessionId, {
      id: e.sessionId,
      cwd: e.cwd || existing?.cwd || "",
      label: basename(e.cwd || existing?.cwd || "") || e.sessionId.slice(0, 6),
      status,
      // `since` tracks when this status began, so a session that stays blocked
      // keeps its original timestamp and we can tell how long you've been holding it up.
      since: existing?.status === status ? existing.since : e.ts,
    });
  }

  /** Drops finished sessions once they've had their moment. */
  prune(now = Date.now()): void {
    for (const [id, s] of this.byId) {
      if (s.status === "done" && now - s.since > DONE_TTL_MS) this.byId.delete(id);
    }
  }

  list(): Session[] {
    return [...this.byId.values()].sort((a, b) => a.since - b.since);
  }
}
