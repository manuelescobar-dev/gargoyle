import type { ScheduledSource } from "../domain/schedule.ts";
import { parseEvery } from "../domain/schedule.ts";

/**
 * The pull door: commands you've declared, run on a schedule, whose output becomes embers
 * or nudges.
 *
 * ```json
 * { "sources": [ { "run": "~/bin/check-ci", "every": "5m" } ] }
 * ```
 *
 * The hub never learns what CI is. It learns that a command produced something worth a
 * glance — which is what keeps this a surface rather than a suite.
 */
export function readSources(config: unknown): { sources: ScheduledSource[]; problems: string[] } {
  const sources: ScheduledSource[] = [];
  const problems: string[] = [];

  const declared = (config as { sources?: unknown })?.sources;
  if (!Array.isArray(declared)) return { sources, problems };

  for (const [index, entry] of declared.entries()) {
    const where = `sources[${index}]`;

    if (typeof entry !== "object" || entry === null) {
      problems.push(`${where}: not an object`);
      continue;
    }

    const { run, every, whenBusy } = entry as Record<string, unknown>;
    if (typeof run !== "string" || run.trim().length === 0) {
      problems.push(`${where}: needs a "run" command`);
      continue;
    }

    const everyMs = typeof every === "string" ? parseEvery(every) : null;
    if (everyMs === null) {
      // Named rather than silently dropped: a source that never runs looks exactly like
      // one that never finds anything.
      problems.push(`${where}: couldn't read "every": ${JSON.stringify(every)}`);
      continue;
    }

    sources.push({ run, everyMs, whenBusy: whenBusy === true });
  }

  return { sources, problems };
}
