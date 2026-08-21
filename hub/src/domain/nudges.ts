export type Nudge = {
  text: string;
  /// A command to hand your answer to. Gargoyle stores nothing itself — decisions/0005.
  replyTo?: string;
  /// Dropped rather than asked late once this long has passed.
  expiresInMs?: number;
};

type Queued = Nudge & { queuedAt: number };

/** Moments where you're already looking at the creature, so its attention costs nothing. */
const GLANCES = new Set(["glance", "finished", "returned", "clicked"]);

/**
 * Things worth asking, held until asking is free.
 *
 * A nudge becoming *eligible* and a nudge becoming *visible* are two different events.
 * Everything here exists to keep them apart — that's the difference between a companion
 * and a notification.
 */
export class NudgeQueue {
  private queue: Queued[] = [];

  get size(): number {
    return this.queue.length;
  }

  add(nudge: Nudge, now = Date.now()): void {
    this.queue.push({ ...nudge, queuedAt: now });
  }

  /**
   * Hands over one nudge if this is a moment you're already looking, and nothing more
   * urgent is happening. Drops anything that has gone stale on the way.
   */
  takeFor(moment: string, now = Date.now(), state: { busy?: boolean } = {}): Nudge | null {
    // Expire first, so a stale nudge is discarded even at a moment we wouldn't ask.
    this.queue = this.queue.filter(
      (n) => n.expiresInMs === undefined || now - n.queuedAt <= n.expiresInMs,
    );

    if (!GLANCES.has(moment)) return null;
    // Mid-decision about something that matters is not the moment to ask about lunch.
    if (state.busy) return null;

    return this.queue.shift() ?? null;
  }
}
