import { createServer, type Server } from "node:http";
import { fromClaudeHook } from "./sources/claude-code.ts";
import { Sessions } from "./domain/sessions.ts";
import { snapshot } from "./domain/state.ts";

export const PORT = 7373;

/**
 * Two routes. POST /event takes anything that can produce JSON — a Claude Code hook,
 * a cron job, an iOS Shortcut. GET /state is what the surface reads.
 *
 * No framework. It's two routes.
 */
export function createHub(sessions = new Sessions()) {
  // `doctor` needs to distinguish "wired up correctly" from "wired up and never fired",
  // which is the failure that otherwise looks exactly like everything being fine.
  const startedAt = Date.now();
  let eventsReceived = 0;

  const server: Server = createServer((req, res) => {
    if (req.method === "POST" && req.url === "/event") {
      let body = "";
      req.on("data", (c) => {
        body += c;
      });
      req.on("end", () => {
        // A malformed hook must never take the hub down — every agent on the
        // machine is feeding this endpoint.
        try {
          const event = fromClaudeHook(JSON.parse(body));
          if (event) {
            sessions.apply(event);
            eventsReceived++;
          }
        } catch {
          // ignored on purpose: unparseable input is the sender's problem
        }
        res.writeHead(204).end();
      });
      return;
    }

    if (req.method === "GET" && req.url === "/state") {
      sessions.prune();
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify(snapshot(sessions.list())));
      return;
    }

    if (req.method === "GET" && req.url === "/health") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ uptimeMs: Date.now() - startedAt, eventsReceived }));
      return;
    }

    res.writeHead(404).end();
  });

  return { server, sessions, health: () => ({ eventsReceived }) };
}
