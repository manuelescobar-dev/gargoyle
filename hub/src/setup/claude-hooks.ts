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

type HookEntry = { type: string; command: string; timeout?: number };

const timeoutFor = (event: string) =>
  event === "PermissionRequest" ? { timeout: DECIDE_HOOK_TIMEOUT } : {};
type HookGroup = { matcher?: string; hooks: HookEntry[] };
type Settings = Record<string, unknown>;

/**
 * The hook runs inside the agent's own shell, so it already knows which terminal tab it's
 * in — far more reliable than us guessing later from window titles. Sent as headers so the
 * payload from Claude Code passes through untouched.
 */
const commandFor = (port: number, maxSeconds = 2) =>
  `curl -s -m ${maxSeconds} -X POST ` +
  `-H "X-Gargoyle-Term: $TERM_SESSION_ID" -H "X-Gargoyle-Term-App: $TERM_PROGRAM" ` +
  `http://127.0.0.1:${port}/event --data-binary @- ${GARGOYLE_MARKER}`;

/**
 * A permission request is the one hook that waits on a human, so it gets a longer leash
 * and its own Claude Code `timeout`. Both are hard stops: when either fires the hook
 * produces nothing, and Claude Code falls back to its normal terminal prompt exactly as
 * if Gargoyle weren't installed.
 *
 * curl's own limit is deliberately under Claude Code's, so we're always the one to give up.
 */
const DECIDE_CURL_SECONDS = 25;
const DECIDE_HOOK_TIMEOUT = 30;

/** Identified by the marker, not by the URL — so changing the port doesn't orphan an install. */
const isOurs = (hook: HookEntry) =>
  typeof hook?.command === "string" && hook.command.includes(GARGOYLE_MARKER);

const groupsFor = (settings: Settings, event: string): HookGroup[] =>
  ((settings.hooks as Record<string, HookGroup[]>)?.[event] ?? []) as HookGroup[];

export function withGargoyleHooks(input: Settings, port = HUB_PORT) {
  const settings = structuredClone(input);
  settings.hooks ??= {};
  const hooks = settings.hooks as Record<string, HookGroup[]>;

  const added: string[] = [];
  const alreadyPresent: string[] = [];
  const upgraded: string[] = [];
  const current = commandFor(port);

  const wanted: [string, string | undefined][] = [
    ...HOOK_EVENTS.map((e) => [e, undefined] as [string, undefined]),
    ...Object.entries(NARROWED_EVENTS),
  ];

  const commandForEvent = (event: string) =>
    event === "PermissionRequest" ? commandFor(port, DECIDE_CURL_SECONDS) : current;

  for (const [event, matcher] of wanted) {
    const existing = groupsFor(settings, event);

    if (existing.some((group) => (group.hooks ?? []).some(isOurs))) {
      // Ours is already here — but it may be an older command. Rewrite it in place,
      // otherwise every change we ever make to the hook reaches nobody.
      const wantedCommand = commandForEvent(event);
      let changed = false;
      hooks[event] = existing.map((group) => ({
        ...group,
        hooks: (group.hooks ?? []).map((hook) => {
          if (!isOurs(hook) || hook.command === wantedCommand) return hook;
          changed = true;
          return { ...hook, command: wantedCommand, ...timeoutFor(event) };
        }),
      }));

      (changed ? upgraded : alreadyPresent).push(event);
      continue;
    }

    // Appended, never substituted. Someone else's hooks are none of our business.
    const group: HookGroup = {
      hooks: [{ type: "command", command: commandForEvent(event), ...timeoutFor(event) }],
    };
    if (matcher) group.matcher = matcher;

    hooks[event] = [...existing, group];
    added.push(event);
  }

  return { settings, added, alreadyPresent, upgraded };
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
