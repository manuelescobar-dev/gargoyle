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
export function createHub(
  sessions = new Sessions(),
  onChange: (s: ReturnType<typeof snapshot>) => void = () => {},
  onAction: (id: string) => void = () => {},
) {
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
          // The hook runs inside the agent's own terminal, so it can tell us which one.
          const header = (name: string) => {
            const value = req.headers[name];
            const text = Array.isArray(value) ? value[0] : value;
            return text && text.length > 0 ? text : undefined;
          };
          const event = fromClaudeHook(JSON.parse(body), Date.now(), {
            app: header("x-gargoyle-term-app"),
            term: header("x-gargoyle-term"),
          });
          if (event) {
            sessions.apply(event);
            eventsReceived++;
            sessions.prune();
            onChange(snapshot(sessions.list()));
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

    // The pet reports which item was chosen; it has no idea what the id means, which is
    // exactly the point — all semantics stay on this side.
    if (req.method === "POST" && req.url === "/action") {
      let body = "";
      req.on("data", (c) => {
        body += c;
      });
      req.on("end", () => {
        try {
          const { id } = JSON.parse(body);
          if (typeof id === "string") onAction(id);
        } catch {
          // a malformed action is the sender's problem, not a reason to fall over
        }
        res.writeHead(204).end();
      });
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
