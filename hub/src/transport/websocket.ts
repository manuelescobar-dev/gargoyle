import type { Server } from "node:http";
import { WebSocketServer } from "ws";
import type { Snapshot } from "../domain/state.ts";
import { Broadcaster } from "./broadcast.ts";

/**
 * Pushes snapshots to connected pets.
 *
 * Replaces polling: the pet stops asking and starts being told, which is also what
 * makes `unknown` honest — a dropped socket is immediate and unambiguous, where a
 * missed poll is just a pause.
 */
export function attachWebSocket(server: Server, options: { onLastClientGone?: () => void } = {}) {
  const clients = new Set<import("ws").WebSocket>();
  const broadcaster = new Broadcaster((payload) => {
    for (const client of clients) {
      if (client.readyState === client.OPEN) client.send(payload);
    }
  });

  let lastMenu: string | null = null;
  const wss = new WebSocketServer({ server, path: "/socket" });
  // ws forwards the http server's errors to its own listeners. Swallowed here because
  // the hub installs a real handler on the server itself.
  wss.on("error", () => {});

  wss.on("connection", (socket) => {
    clients.add(socket);
    // Don't make a pet that just connected wait for the next change to learn anything.
    broadcaster.greet((payload) => socket.send(payload));
    if (lastMenu) socket.send(lastMenu);
    const forget = () => {
      clients.delete(socket);
      if (clients.size === 0) options.onLastClientGone?.();
    };
    socket.on("close", forget);
    socket.on("error", forget);
  });

  const sendAll = (payload: string) => {
    for (const client of clients) {
      if (client.readyState === client.OPEN) client.send(payload);
    }
  };

  return {
    publish: (snapshot: Snapshot) => broadcaster.publish(snapshot),
    /// A situation key, not words. The creature's persona decides what that sounds like,
    /// so swapping the creature swaps the voice.
    speak: (situation: string) => sendAll(JSON.stringify({ t: "bubble", situation })),
    /// A nudge, in words the source chose. Unlike `speak`, the creature's persona has no
    /// say here — someone else's question shouldn't come out in its voice.
    say: (id: string, text: string, replyable: boolean) =>
      sendAll(JSON.stringify({ t: "bubble", id, text, replyable })),
    /// Whether the creature is working on something you said. A silent gap reads as
    /// broken; this is what makes a slow answer legible as a slow answer.
    thinking: (on: boolean) => sendAll(JSON.stringify({ t: "thinking", on })),
    /// Puts a permission question in front of the user.
    ask: (id: string, summary: string) => sendAll(JSON.stringify({ t: "request", id, summary })),
    /// Takes the question away again — answered, or nobody answered in time.
    withdraw: (id: string) => sendAll(JSON.stringify({ t: "withdraw", id })),
    /// Asks the pet to raise a terminal. It's the surface's job because only a real app
    /// can be granted Automation permission.
    focus: (terminal: { app?: string; term?: string }) =>
      sendAll(JSON.stringify({ t: "focus", ...terminal })),
    sendMenu: (items: Array<{ id: string; label: string }>) => {
      const payload = JSON.stringify({ t: "menu", items });
      if (payload === lastMenu) return; // an unchanged menu is not worth a frame
      lastMenu = payload;
      sendAll(payload);
    },
    clientCount: () => clients.size,
  };
}
