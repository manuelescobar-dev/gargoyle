import type { Event, EventType } from "../domain/event.ts";

/**
 * Anything that can produce a line of JSON.
 *
 * ```bash
 * curl -X POST localhost:7373/event -d '{"id":"ci","label":"build","status":"running"}'
 * ```
 *
 * No SDK, no plugin API, no language binding — a shell script, a cron job, an iOS
 * Shortcut and another app all arrive the same way. This is what makes
 * decisions/0005 true rather than aspirational.
 */

/** The vocabulary a source speaks, mapped to what the domain calls it. */
const STATUSES: Record<string, EventType> = {
  running: "active",
  blocked: "blocked",
  done: "finished",
  failed: "failed",
  gone: "ended",
};

/** Long enough for anything sensible, short enough that nothing can flood the creature. */
const MAX_ID = 128;

/**
 * Returns null for anything it can't read. This endpoint is open to everything on the
 * machine, so it refuses rather than guesses, and never throws.
 */
export function fromGeneric(payload: unknown, now = Date.now()): Event | null {
  if (typeof payload !== "object" || payload === null) return null;
  const p = payload as Record<string, unknown>;

  // A Claude Code payload belongs to the other source; two readers claiming one event
  // would double-count it.
  if ("hook_event_name" in p) return null;

  const id = typeof p.id === "string" ? p.id : null;
  if (!id || id.length === 0 || id.length > MAX_ID) return null;

  const type = STATUSES[String(p.status)];
  if (!type) return null;

  return {
    source: typeof p.source === "string" ? p.source : "external",
    sessionId: id,
    cwd: "",
    label: typeof p.label === "string" && p.label.length > 0 ? p.label.slice(0, MAX_ID) : id,
    type,
    ts: now,
    terminal: undefined,
  };
}
