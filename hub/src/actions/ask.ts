import { execFile } from "node:child_process";

/**
 * Saying something to the creature unprompted, and hearing back.
 *
 * Unlike a nudge reply — which hands your answer somewhere and forgets — this captures
 * what the command printed so it can come back as a bubble. That's the whole difference
 * between answering the creature and talking to it.
 *
 * You always start it, it answers once, and it never follows up. Which keeps
 * *personality is voice, not volume* intact: this never creates a reason to speak.
 */

/** A bubble is a glance, not a document. */
const MAX_REPLY = 400;

export function ask(command: string, text: string, timeoutMs = 60_000): Promise<string | null> {
  return new Promise((resolve) => {
    const child = execFile(
      "/bin/sh",
      ["-c", command],
      { timeout: timeoutMs, maxBuffer: 256 * 1024, killSignal: "SIGKILL" },
      (error, stdout) => {
        if (error) {
          console.log(`ask: ${command} failed — ${error.message}`);
          return resolve(null);
        }

        const said = String(stdout).trim();
        resolve(said ? said.slice(0, MAX_REPLY) : null);
      },
    );

    // A command that exits before reading stdin closes the pipe under us; the write then
    // lands as an unhandled EPIPE. Same trap as reply.ts.
    child.stdin?.on("error", () => {});
    child.stdin?.end(text);
  });
}
