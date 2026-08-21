import type { Snapshot } from "../domain/state.ts";

type Send = (payload: string) => void;

/**
 * Publishes complete snapshots to connected pets.
 *
 * Snapshots, never diffs — decisions/0003. The pet has nowhere to accumulate state,
 * so it can't drift out of sync with us.
 *
 * And only on change: an idle machine should produce no traffic at all.
 */
export class Broadcaster {
  private last: string | null = null;
  private readonly send: Send;

  // Written out rather than a parameter property: Node's type-stripping only removes
  // types, and a parameter property emits an assignment. See CLAUDE.md.
  constructor(send: Send) {
    this.send = send;
  }

  publish(snapshot: Snapshot): void {
    const payload = JSON.stringify({ t: "state", ...snapshot });
    if (payload === this.last) return;
    this.last = payload;
    this.send(payload);
  }

  /** A pet that connects mid-silence must not wait for the next change to learn anything. */
  greet(send: Send): void {
    send(
      this.last ?? JSON.stringify({ t: "state", state: "idle", embers: [], mood: 0, blocked: 0 }),
    );
  }
}
