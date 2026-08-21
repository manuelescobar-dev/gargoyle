export type ScheduledSource = {
  run: string;
  everyMs: number;
  /// Most sources stand down while you're mid-decision. A few genuinely shouldn't.
  whenBusy?: boolean;
};

export type ScheduleState = {
  now: number;
  lastRunAt?: number;
  running: boolean;
  busy: boolean;
};

/** Below this, a source is a busy-loop wearing a schedule. */
const FLOOR_MS = 10_000;

/** `30s` · `5m` · `2h`. Returns null for anything else rather than guessing. */
export function parseEvery(text: string): number | null {
  const match = /^(\d+)(s|m|h)$/.exec(text.trim());
  if (!match) return null;

  const scale = { s: 1_000, m: 60_000, h: 3_600_000 }[match[1 + 1] as "s" | "m" | "h"];
  const ms = Number(match[1]) * scale;
  return ms >= FLOOR_MS ? ms : null;
}

/**
 * Whether to run this source now.
 *
 * Gating matters more than scheduling. An unconditional timer is the trigger of last
 * resort, so by default nothing new starts while an agent is waiting on you — that's
 * attention already spoken for.
 */
export function dueNow(source: ScheduledSource, state: ScheduleState): boolean {
  if (state.running) return false; // a slow source must not stack up copies of itself
  if (state.busy && !source.whenBusy) return false;
  if (state.lastRunAt === undefined) return true;
  return state.now - state.lastRunAt >= source.everyMs;
}
