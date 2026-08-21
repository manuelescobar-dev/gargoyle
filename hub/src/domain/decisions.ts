export type Decision = "allow" | "deny";

/**
 * Permission requests waiting on a human.
 *
 * The safety property that matters: **a request that isn't answered resolves to `null`**,
 * which the caller turns into "no opinion" and Claude Code handles exactly as if Gargoyle
 * weren't installed. Nothing here may ever leave an agent blocked because a creature was
 * on screen and nobody clicked it.
 */
export class PendingDecisions {
  private waiting = new Map<string, (decision: Decision | null) => void>();

  get size(): number {
    return this.waiting.size;
  }

  /** Resolves with the decision, or `null` once `timeoutMs` passes with no answer. */
  ask(id: string, timeoutMs: number): Promise<Decision | null> {
    return new Promise((resolve) => {
      const settle = (decision: Decision | null) => {
        clearTimeout(timer);
        this.waiting.delete(id);
        resolve(decision);
      };

      const timer = setTimeout(() => settle(null), timeoutMs);
      // Don't hold the process open for a prompt nobody is going to answer.
      timer.unref?.();

      this.waiting.set(id, settle);
    });
  }

  /** Silently ignores ids nobody is waiting on, and second answers. First click wins. */
  answer(id: string, decision: Decision): void {
    this.waiting.get(id)?.(decision);
  }

  /** Releases every waiter — used when the surface goes away mid-flight. */
  abandonAll(): void {
    for (const settle of [...this.waiting.values()]) settle(null);
  }
}
