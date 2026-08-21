import { runSource } from "./actions/run-source.ts";
import type { Event } from "./domain/event.ts";
import { dueNow, type ScheduledSource } from "./domain/schedule.ts";

/** How often we look for something due. Cheap: an array check, no work. */
const TICK_MS = 5_000;

type Sink = {
  ember: (event: Event) => void;
  nudge: (nudge: { text: string; replyTo?: string; expiresInMs?: number }) => void;
  busy: () => boolean;
};

/**
 * Runs declared sources on their schedule.
 *
 * If nothing is declared the timer never starts — a hub with no sources should cost
 * nothing at all.
 */
export function startScheduler(sources: ScheduledSource[], sink: Sink) {
  if (sources.length === 0) return { stop: () => {} };

  const lastRunAt = new Map<string, number>();
  const running = new Set<string>();

  const tick = () => {
    const now = Date.now();
    const busy = sink.busy();

    for (const source of sources) {
      const state = {
        now,
        lastRunAt: lastRunAt.get(source.run),
        running: running.has(source.run),
        busy,
      };
      if (!dueNow(source, state)) continue;

      running.add(source.run);
      // Stamped before the run, not after, so a slow source keeps its cadence rather
      // than drifting later every time.
      lastRunAt.set(source.run, now);

      void runSource(source.run).then((output) => {
        running.delete(source.run);
        if (output.problem) console.log(`source ${source.run}: ${output.problem}`);
        for (const { event } of output.embers) sink.ember(event);
        for (const nudge of output.nudges) sink.nudge(nudge);
      });
    }
  };

  const timer = setInterval(tick, TICK_MS);
  timer.unref?.();
  tick(); // don't make the first source wait out a tick

  return { stop: () => clearInterval(timer) };
}
