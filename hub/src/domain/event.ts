/**
 * The one event shape. Every source normalizes to this at the boundary — a coding agent,
 * a cron job, an iOS Shortcut all arrive here looking identical.
 *
 * This type lives in the domain, not in any source, because the domain must not know that
 * Claude Code exists. That's what keeps sources from leaking into the state machine.
 */
export type Event = {
  source: string;
  sessionId: string;
  cwd: string;
  type: EventType;
  ts: number;
  /// What to call this in the menu. Agents don't set it — their worktree is a better
  /// name than anything they could invent — but a generic source has no cwd to fall
  /// back on.
  label?: string;
  /// Where this session is running, when the source can tell us.
  terminal?: Terminal;
};

/** Enough to raise the window a session lives in. */
export type Terminal = { app?: string; term?: string };

export type EventType = "started" | "active" | "blocked" | "finished" | "failed" | "ended";
