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
};

export type EventType = "started" | "active" | "blocked" | "finished" | "failed" | "ended";
