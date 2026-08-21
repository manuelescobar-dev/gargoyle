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
export function attachWebSocket(server: Server) {
  const clients = new Set<import("ws").WebSocket>();
  const broadcaster = new Broadcaster((payload) => {
    for (const client of clients) {
      if (client.readyState === client.OPEN) client.send(payload);
    }
  });

  const wss = new WebSocketServer({ server, path: "/socket" });

  wss.on("connection", (socket) => {
    clients.add(socket);
    // Don't make a pet that just connected wait for the next change to learn anything.
    broadcaster.greet((payload) => socket.send(payload));
    socket.on("close", () => clients.delete(socket));
    socket.on("error", () => clients.delete(socket));
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
    clientCount: () => clients.size,
  };
}
