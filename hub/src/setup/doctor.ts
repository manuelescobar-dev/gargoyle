export type Checks = {
  hubUp: boolean;
  hooksWired: boolean;
  agentLoaded: boolean;
  eventsSeen: number;
  creatureRunning?: boolean;
};

/**
 * Pure so the verdict can be tested without a machine in a particular state.
 *
 * `✓` fine · `✗` broken, and `ok` goes false · `·` worth knowing, not broken.
 */
export function diagnose(checks: Checks): { ok: boolean; lines: string[] } {
  const lines: string[] = [];
  let ok = true;

  if (checks.hubUp) {
    lines.push("✓ hub is running on 127.0.0.1:7373");
  } else {
    lines.push("✗ hub isn't running — `npm start`, or `gargoyle install` to run it at login");
    ok = false;
  }

  if (checks.hooksWired) {
    lines.push("✓ Claude Code hooks are wired");
  } else {
    lines.push("✗ Claude Code hooks aren't wired — run `gargoyle install`");
    ok = false;
  }

  // Not fatal: plenty of people would rather run the hub themselves.
  lines.push(
    checks.agentLoaded
      ? "✓ launch agent loaded — the hub starts at login"
      : "· launch agent isn't loaded, so the hub won't start at login (`gargoyle install`)",
  );

  if (checks.creatureRunning !== undefined) {
    lines.push(
      checks.creatureRunning
        ? "✓ creature is on screen"
        : "· creature isn't running — build it with `pet/make-app.sh`, then `gargoyle install`",
    );
  }

  if (checks.eventsSeen > 0) {
    lines.push(`✓ ${checks.eventsSeen} event${checks.eventsSeen === 1 ? "" : "s"} received`);
  } else if (checks.hubUp && checks.hooksWired) {
    // The nastiest state: everything looks installed, so you assume it works, and
    // nothing has ever arrived. Silence must not read as health.
    lines.push(
      "✗ no events have arrived yet — run an agent, or check the hooks point at this port",
    );
    ok = false;
  } else {
    lines.push("· no events yet");
  }

  return { ok, lines };
}
