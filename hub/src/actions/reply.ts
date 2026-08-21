import { execFile } from "node:child_process";

/**
 * Hands your answer to whatever the nudge said should receive it.
 *
 * Gargoyle stores nothing itself — where your data lives is your business, which is what
 * keeps this a surface rather than a suite. The command came from a source you set up, and
 * the answer arrives on stdin so nothing has to be escaped into a shell line.
 */
export function deliverReply(command: string, answer: string): void {
  // Run through a shell so `~/bin/log-food` and pipelines both work the way you'd expect
  // when you wrote them into your own config.
  const child = execFile("/bin/sh", ["-c", command], { timeout: 10_000 }, (error) => {
    if (error) console.log(`reply: ${command} failed — ${error.message}`);
  });
  child.stdin?.end(answer);
}
