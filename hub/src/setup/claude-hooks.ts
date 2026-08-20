/**
 * Wiring Claude Code's hooks to the hub.
 *
 * Pure on purpose — this edits a file the user depends on every day, so the merge
 * logic is tested without ever touching a real filesystem. The CLI is the only part
 * that writes.
 *
 * Not in `sources/` because it doesn't produce Events. It's setup.
 */

/** A shell comment, so it's inert to curl and unambiguous to us. */
export const GARGOYLE_MARKER = "# gargoyle";

export const HUB_PORT = 7373;

/**
 * The hooks worth listening to.
 *
 * `Notification` carries a matcher because it also fires for `auth_success` and
 * `agent_completed` — without narrowing it, a successful login would make the
 * creature ask for your attention. `PermissionRequest` is the precise signal;
 * the notification matchers cover idle-waiting, which the parser can't see.
 *
 * SessionEnd matters as much as the rest — it's how a session leaves the registry
 * instead of lingering as a ghost ember.
 */
export const HOOK_EVENTS = [
  "SessionStart",
  "PermissionRequest",
  "PermissionDenied",
  "Stop",
  "StopFailure",
  "SubagentStop",
  "SessionEnd",
] as const;

/** Events we only want some of. The value is the settings.json `matcher`. */
export const NARROWED_EVENTS: Record<string, string> = {
  Notification: "idle_prompt|agent_needs_input",
};

type HookEntry = { type: string; command: string };
type HookGroup = { matcher?: string; hooks: HookEntry[] };
type Settings = Record<string, unknown>;

const commandFor = (port: number) =>
  `curl -s -m 2 -X POST http://127.0.0.1:${port}/event --data-binary @- ${GARGOYLE_MARKER}`;

/** Identified by the marker, not by the URL — so changing the port doesn't orphan an install. */
const isOurs = (hook: HookEntry) =>
  typeof hook?.command === "string" && hook.command.includes(GARGOYLE_MARKER);

const groupsFor = (settings: Settings, event: string): HookGroup[] =>
  ((settings.hooks as Record<string, HookGroup[]>)?.[event] ?? []) as HookGroup[];

export function withGargoyleHooks(input: Settings, port = HUB_PORT) {
  const settings = structuredClone(input);
  const hooks = ((settings.hooks ??= {}) as Record<string, HookGroup[]>);

  const added: string[] = [];
  const alreadyPresent: string[] = [];

  const wanted: [string, string | undefined][] = [
    ...HOOK_EVENTS.map((e) => [e, undefined] as [string, undefined]),
    ...Object.entries(NARROWED_EVENTS),
  ];

  for (const [event, matcher] of wanted) {
    const existing = groupsFor(settings, event);

    if (existing.some((group) => (group.hooks ?? []).some(isOurs))) {
      alreadyPresent.push(event);
      hooks[event] = existing;
      continue;
    }

    // Appended, never substituted. Someone else's hooks are none of our business.
    const group: HookGroup = { hooks: [{ type: "command", command: commandFor(port) }] };
    if (matcher) group.matcher = matcher;

    hooks[event] = [...existing, group];
    added.push(event);
  }

  return { settings, added, alreadyPresent };
}

export function withoutGargoyleHooks(input: Settings): Settings {
  const settings = structuredClone(input);
  const hooks = settings.hooks as Record<string, HookGroup[]> | undefined;
  if (!hooks) return settings;

  for (const [event, groups] of Object.entries(hooks)) {
    const kept = groups
      .map((group) => ({ ...group, hooks: (group.hooks ?? []).filter((h) => !isOurs(h)) }))
      .filter((group) => group.hooks.length > 0);

    if (kept.length) hooks[event] = kept;
    else delete hooks[event];
  }

  // Leave no trace: if we created the hooks object, we take it with us.
  if (Object.keys(hooks).length === 0) delete settings.hooks;
  return settings;
}
