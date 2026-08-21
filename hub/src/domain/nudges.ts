export type Nudge = {
  text: string;
  /// A command to hand your answer to. Gargoyle stores nothing itself — decisions/0005.
  replyTo?: string;
  /// Dropped rather than asked late once this long has passed.
  expiresInMs?: number;
};

type Queued = Nudge & { queuedAt: number };

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
   * Hands over one nudge, if the caller says now is a moment worth asking at.
   *
   * *Whether* it's such a moment is not decided here — that's the interruption ladder's
   * job, and it's the only place that decision is allowed to live. This just holds things
   * and drops what has gone stale on the way.
   */
  take(allowed: boolean, now = Date.now()): Nudge | null {
    // Expire first, so a stale nudge is discarded even at a moment we wouldn't ask.
    this.queue = this.queue.filter(
      (n) => n.expiresInMs === undefined || now - n.queuedAt <= n.expiresInMs,
    );

    return allowed ? (this.queue.shift() ?? null) : null;
  }
}
