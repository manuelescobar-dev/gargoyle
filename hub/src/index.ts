import { PendingDecisions } from "./domain/decisions.ts";
import { menuFor } from "./domain/menu.ts";
import { Sessions } from "./domain/sessions.ts";
import type { Snapshot } from "./domain/state.ts";
import { situationFor } from "./domain/voice.ts";
import { createHub, PORT } from "./server.ts";
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
    socket?.sendMenu(menuFor(snapshot));

    // Speaks rarely, and only about things its body doesn't already show.
    const situation = situationFor(previous, snapshot);
    if (situation) socket?.speak(situation);
    previous = snapshot;
  },

  onAction: (id) => {
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
});

socket = attachWebSocket(server, {
  // A surface that disappears mid-question must not leave agents hanging.
  onLastClientGone: () => pending.abandonAll(),
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`gargoyle hub listening on 127.0.0.1:${PORT}`);
});
