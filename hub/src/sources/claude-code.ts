import type { Event, EventType, Terminal } from "../domain/event.ts";

/**
 * Claude Code sends a hook payload on stdin; a one-line curl forwards it to POST /event.
 * This is the only file in the hub that knows Claude Code exists.
 */
/** Claude Code's `hook_event_name` → what it means to us. */
const HOOK_TYPES: Record<string, EventType> = {
  SessionStart: "started",

  // Routine progress. PostToolUseFailure is here on purpose: a failing test suite or a
  // grep that finds nothing is normal agent work, not a failed session.
  PreToolUse: "active",
  PostToolUse: "active",
  PostToolUseFailure: "active",
  UserPromptSubmit: "active",
  SubagentStart: "active",
  SubagentStop: "active", // a subagent finished; the session itself is still going
  PermissionDenied: "active", // you answered, it moves on

  // The precise "waiting on a human" signal. Notification is deliberately absent —
  // it also fires for auth_success and agent_completed, and the installer narrows it
  // by matcher rather than the parser assuming.
  PermissionRequest: "blocked",

  StopFailure: "failed", // the turn ended on an API error
  Stop: "finished",
  SessionEnd: "ended",
};

/**
 * Returns null for anything we don't recognise rather than throwing — an unknown
 * hook name is a Claude Code version we haven't seen, not a reason to take the hub down.
 */
export function fromClaudeHook(
  payload: unknown,
  now = Date.now(),
  terminal?: Terminal,
): Event | null {
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
    terminal,
  };
}
