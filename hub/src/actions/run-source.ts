import { execFile } from "node:child_process";
import { fromGeneric } from "../sources/generic.ts";
import type { Event } from "../domain/event.ts";

export type SourceOutput = {
  embers: Array<{ id: string; event: Event }>;
  nudges: Array<{ text: string; replyTo?: string; expiresInMs?: number }>;
  problem: string | null;
};

/** One source shouldn't be able to fill the creature's arms, or its memory. */
const MAX_LINES = 100;
const MAX_OUTPUT = 256 * 1024;

/**
 * Runs a declared source and reads what it printed.
 *
 * One JSON object per line — an ember or a nudge, the same shapes anything can POST. These
 * are shell scripts people wrote in a hurry, so nothing here throws: a bad line is skipped,
 * a failing command is reported, and a hanging one is cut off rather than wedging the
 * schedule behind it.
 */
export function runSource(command: string, timeoutMs = 20_000): Promise<SourceOutput> {
  return new Promise((resolve) => {
    execFile(
      "/bin/sh",
      ["-c", command],
      { timeout: timeoutMs, maxBuffer: MAX_OUTPUT, killSignal: "SIGKILL" },
      (error, stdout) => {
        const embers: SourceOutput["embers"] = [];
        const nudges: SourceOutput["nudges"] = [];

        for (const line of String(stdout).split("\n").slice(0, MAX_LINES)) {
          if (!line.trim()) continue;

          let parsed: unknown;
          try {
            parsed = JSON.parse(line);
          } catch {
            continue; // a stray log line is not an error, it's just not for us
          }

          const p = parsed as Record<string, unknown>;
          if (typeof p.text === "string" && p.text.trim()) {
            nudges.push({
              text: p.text.slice(0, 280),
              replyTo: typeof (p.reply_to ?? p.replyTo) === "string"
                ? String(p.reply_to ?? p.replyTo)
                : undefined,
              expiresInMs: typeof p.expires_in_ms === "number" ? p.expires_in_ms : undefined,
            });
            continue;
          }

          const event = fromGeneric(parsed);
          if (event) embers.push({ id: event.sessionId, event });
        }

        resolve({ embers, nudges, problem: error ? error.message : null });
      },
    );
  });
}
