import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { deliverReply } from "./actions/reply.ts";
import { levelFor, type Surroundings } from "./domain/attention.ts";
import { PendingDecisions } from "./domain/decisions.ts";
import { menuFor } from "./domain/menu.ts";
import { type Nudge, NudgeQueue } from "./domain/nudges.ts";
import { Sessions } from "./domain/sessions.ts";
import { type Snapshot, snapshot } from "./domain/state.ts";
import { situationFor } from "./domain/voice.ts";
import { startScheduler } from "./scheduler.ts";
import { createHub, PORT } from "./server.ts";
import { readSources } from "./setup/sources.ts";
import { attachWebSocket } from "./transport/websocket.ts";

/**
 * How long a permission request waits on you before giving up.
 *
 * Giving up costs nothing: Claude Code falls back to its normal terminal prompt, which is
 * what would have happened anyway. So the only question is how long to hold the door open.
 */
const DECISION_TIMEOUT_MS = 20_000;

const sessions = new Sessions();
const pending = new PendingDecisions();

let socket: ReturnType<typeof attachWebSocket> | null = null;
let previous: Snapshot | null = null;
let nextRequestId = 0;
/// What the pet last reported about your desktop. It observes; the hub decides.
let context: { currentSession?: string; undisturbed?: boolean } = {};

/// Everything that wants your attention is measured against these.
function surroundings(moment: string): Surroundings {
  return {
    moment,
    busy: previous?.state === "needs-you",
    undisturbed: context.undisturbed === true,
  };
}

const nudges = new NudgeQueue();
/// Nudges we've asked but not yet heard back on, so a reply knows where to go.
const asked = new Map<string, Nudge>();
let nextNudgeId = 0;

/**
 * Surfaces a queued nudge, but only at a moment you're already looking and nothing more
 * urgent is happening. Asking is free then; interrupting is not.
 */
function maybeNudge(moment: string) {
  const allowed = levelFor({ kind: "nudge" }, surroundings(moment)) === "bubble";
  const nudge = nudges.take(allowed);
  if (!nudge) return;

  const id = `n${++nextNudgeId}`;
  asked.set(id, nudge);
  socket?.say(id, nudge.text, nudge.replyTo !== undefined);
}

/** What the popover shows. Falls back to the worktree when the payload tells us nothing. */
function describe(payload: Record<string, unknown>, fallback: string): string {
  const tool = typeof payload.tool_name === "string" ? payload.tool_name : null;
  const input = payload.tool_input as Record<string, unknown> | undefined;
  const path = typeof input?.file_path === "string" ? input.file_path : null;
  const command = typeof input?.command === "string" ? input.command : null;

  if (tool && path) return `${tool} ${path}`;
  if (tool && command) return `${tool}: ${command.slice(0, 80)}`;
  if (tool) return tool;
  return `${fallback} needs a decision`;
}

const { server } = createHub({
  sessions,

  onChange: (snapshot) => {
    socket?.publish(snapshot);
    socket?.sendMenu(menuFor(snapshot, { now: Date.now(), ...context }));

    // Speaks rarely, and only about things its body doesn't already show.
    // A finished run is a moment you look over, so that's when its own voice is allowed.
    const situation = situationFor(previous, snapshot);
    if (
      situation &&
      levelFor({ kind: "voice", situation }, surroundings("finished")) === "bubble"
    ) {
      socket?.speak(situation);
    }

    const wasRunning = previous?.state === "working" || previous?.state === "needs-you";
    previous = snapshot;

    // A run finishing is a moment you look over anyway.
    if (wasRunning && (snapshot.state === "idle" || snapshot.state === "done")) {
      maybeNudge("finished");
    }
  },

  onAction: (id) => {
    // Opening the popover is the most reliable glance there is.
    if (id === "opened") return maybeNudge("clicked");
    if (!id.startsWith("focus:")) return;

    const session = sessions.find(id.slice("focus:".length));
    if (!session?.terminal) {
      console.log(`focus: no terminal recorded for ${id}`);
      return;
    }

    // The hub works out *which* terminal; the pet raises it. macOS won't grant Automation
    // rights to a launchd agent, so the request would be denied silently. See decisions/0007.
    socket?.focus(session.terminal);
  },

  onPermissionRequest: async (payload, sessionId) => {
    // Nobody watching means nobody to ask. Answer instantly rather than making every
    // tool call wait out a timeout for a creature that isn't on screen.
    if (!socket || socket.clientCount() === 0) return null;

    const id = `r${++nextRequestId}`;
    const summary = describe(payload, sessions.find(sessionId)?.label ?? "an agent");

    socket.ask(id, summary);
    const decision = await pending.ask(id, DECISION_TIMEOUT_MS);
    socket.withdraw(id);

    if (!decision) return null; // nobody answered — behave as if we weren't installed
    return JSON.stringify({
      decision,
      reason: decision === "allow" ? "Approved from Gargoyle" : "Denied from Gargoyle",
    });
  },

  onDecision: (id, decision) => pending.answer(id, decision),

  onNudge: (nudge) => nudges.add(nudge),

  onReply: (id, text) => {
    const nudge = asked.get(id);
    asked.delete(id);
    if (nudge?.replyTo) deliverReply(nudge.replyTo, text);
  },

  onContext: (reported) => {
    context.undisturbed = reported.undisturbed;
    // The pet reports a *terminal* id; the menu ranks by *session*. Only the hub knows
    // which agent is running in which terminal, so the bridge belongs here.
    const terminalId = reported.currentSession;
    const match = terminalId
      ? sessions.list().find((s) => s.terminal?.term?.endsWith(terminalId))
      : undefined;
    context = { currentSession: match?.id, undisturbed: reported.undisturbed };
    // Coming back to a terminal is a glance.
    maybeNudge("returned");
    // Recompute now rather than waiting for the next agent event — you may have switched
    // windows precisely because you're about to open the menu.
    if (previous) socket?.sendMenu(menuFor(previous, { now: Date.now(), ...context }));
  },
});

socket = attachWebSocket(server, {
  // A surface that disappears mid-question must not leave agents hanging.
  onLastClientGone: () => pending.abandonAll(),
});

// Declared sources: commands you run on a schedule whose output becomes embers or nudges.
// Most people won't have any, and a hub with none costs nothing.
const configPath = process.env.GARGOYLE_CONFIG ?? join(homedir(), ".gargoyle", "config.json");
let config: unknown;
try {
  config = existsSync(configPath) ? JSON.parse(readFileSync(configPath, "utf8")) : undefined;
} catch (error) {
  console.log(`config: ${configPath} isn't valid JSON — ${(error as Error).message}`);
}

const { sources, problems } = readSources(config);
for (const problem of problems) console.log(`config: ${problem}`);
if (sources.length) console.log(`config: ${sources.length} source(s) declared`);

startScheduler(sources, {
  ember: (event) => {
    sessions.apply(event);
    sessions.prune();
    const next = snapshot(sessions.list());
    socket?.publish(next);
    socket?.sendMenu(menuFor(next, { now: Date.now(), ...context }));
    previous = next;
  },
  nudge: (nudge) => nudges.add(nudge),
  // Nothing new starts while an agent is waiting on you — that attention is spoken for.
  busy: () => previous?.state === "needs-you",
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`gargoyle hub listening on 127.0.0.1:${PORT}`);
});
