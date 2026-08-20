/**
 * Claude Code sends a hook payload on stdin; a one-line curl forwards it here.
 * This turns that vendor shape into the one event shape the rest of the hub speaks.
 *
 * Every source normalizes to this. An iOS Shortcut, a cron job, and a coding agent
 * all arrive as the same thing, which is what keeps sources from leaking into the
 * state machine.
 */
export type Event = {
  source: string;
  sessionId: string;
  cwd: string;
  type: EventType;
  ts: number;
};

export type EventType = "started" | "active" | "blocked" | "finished" | "ended";

/** Claude Code's `hook_event_name` → what it means to us. */
const HOOK_TYPES: Record<string, EventType> = {
  SessionStart: "started",
  PreToolUse: "active",
  PostToolUse: "active",
  UserPromptSubmit: "active",
  Notification: "blocked", // fires when it needs permission or is idle-waiting
  Stop: "finished",
  SubagentStop: "active", // a subagent finished; the session itself is still going
  SessionEnd: "ended",
};

/**
 * Returns null for anything we don't recognise rather than throwing — an unknown
 * hook name is a Claude Code version we haven't seen, not a reason to take the hub down.
 */
export function fromClaudeHook(payload: unknown, now = Date.now()): Event | null {
  if (typeof payload !== "object" || payload === null) return null;
  const p = payload as Record<string, unknown>;

  const type = HOOK_TYPES[String(p.hook_event_name)];
  if (!type) return null;

  const sessionId = typeof p.session_id === "string" ? p.session_id : null;
  if (!sessionId) return null;

  return {
    source: "claude-code",
    sessionId,
    cwd: typeof p.cwd === "string" ? p.cwd : "",
    type,
    ts: now,
  };
}
