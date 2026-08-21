import { createServer, type Server } from "node:http";
import { Sessions } from "./domain/sessions.ts";
import { snapshot } from "./domain/state.ts";
import { fromClaudeHook } from "./sources/claude-code.ts";
import { fromGeneric } from "./sources/generic.ts";

export const PORT = 7373;

export type HubHandlers = {
  sessions?: Sessions;
  onChange?: (s: ReturnType<typeof snapshot>) => void;
  onAction?: (id: string) => void;
  /**
   * Called when a tool call needs a decision. Returns the JSON body to hand back to
   * Claude Code, or `null` to say nothing — which Claude Code treats exactly as if
   * Gargoyle weren't installed.
   */
  onPermissionRequest?: (
    payload: Record<string, unknown>,
    sessionId: string,
  ) => Promise<string | null>;
  onDecision?: (id: string, decision: "allow" | "deny") => void;
  /// The pet reporting what it can see of the desktop. Data, not decisions.
  onContext?: (context: { currentSession?: string }) => void;
  /// Something worth asking, queued until asking is free.
  onNudge?: (nudge: { text: string; replyTo?: string; expiresInMs?: number }) => void;
  /// Your answer to a nudge, on its way to wherever you said it should go.
  onReply?: (id: string, text: string) => void;
};

/** Collects a request body, then hands it over. */
const readBody = (req: Parameters<Parameters<typeof createServer>[0]>[0]) =>
  new Promise<string>((resolve) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => resolve(body));
  });

/**
 * POST /event     anything that produces JSON — hooks, cron jobs, Shortcuts
 * POST /action    the pet reporting a chosen menu item
 * POST /decision  the pet answering a permission request
 * GET  /state     the current snapshot
 * GET  /health    for `doctor`
 *
 * No framework. It's five routes.
 */
export function createHub(options: HubHandlers = {}) {
  const sessions = options.sessions ?? new Sessions();
  const onChange = options.onChange ?? (() => {});

  // `doctor` needs to tell "wired up correctly" from "wired up and never fired", which is
  // the failure that otherwise looks exactly like everything being fine.
  const startedAt = Date.now();
  let eventsReceived = 0;

  const server: Server = createServer((req, res) => {
    const done = (status: number, body?: string) => {
      if (body) res.writeHead(status, { "content-type": "application/json" }).end(body);
      else res.writeHead(status).end();
    };

    if (req.method === "POST" && req.url === "/event") {
      void (async () => {
        const body = await readBody(req);
        try {
          // The hook runs inside the agent's own terminal, so it can tell us which one.
          const header = (name: string) => {
            const value = req.headers[name];
            const text = Array.isArray(value) ? value[0] : value;
            return text && text.length > 0 ? text : undefined;
          };

          const payload = JSON.parse(body) as Record<string, unknown>;
          // Claude Code first, then anything else. Each reader refuses what isn't its
          // own, so an event can never be claimed twice.
          const event =
            fromClaudeHook(payload, Date.now(), {
              app: header("x-gargoyle-term-app"),
              term: header("x-gargoyle-term"),
            }) ?? fromGeneric(payload, Date.now());

          if (event) {
            sessions.apply(event);
            eventsReceived++;
            sessions.prune();
            onChange(snapshot(sessions.list()));

            // Only this one waits, and only if someone is there to answer.
            if (event.type === "blocked" && options.onPermissionRequest) {
              const answer = await options.onPermissionRequest(payload, event.sessionId);
              if (answer) return done(200, answer);
            }
          }
        } catch {
          // A bad payload — or a failure while asking — must never block an agent.
        }
        done(204);
      })();
      return;
    }

    // The pet reports which item was chosen; it has no idea what the id means.
    if (req.method === "POST" && req.url === "/action") {
      void readBody(req).then((body) => {
        try {
          const { id } = JSON.parse(body);
          if (typeof id === "string") options.onAction?.(id);
        } catch {
          // the sender's problem, not ours
        }
        done(204);
      });
      return;
    }

    if (req.method === "POST" && req.url === "/decision") {
      void readBody(req).then((body) => {
        try {
          const { id, decision } = JSON.parse(body);
          if (typeof id === "string" && (decision === "allow" || decision === "deny")) {
            options.onDecision?.(id, decision);
          }
        } catch {
          // the sender's problem, not ours
        }
        done(204);
      });
      return;
    }

    if (req.method === "POST" && req.url === "/nudge") {
      void readBody(req).then((body) => {
        try {
          const { text, reply_to, replyTo, expires_in_ms } = JSON.parse(body);
          if (typeof text === "string" && text.trim().length > 0) {
            options.onNudge?.({
              text: text.slice(0, 280),
              replyTo: typeof (reply_to ?? replyTo) === "string" ? (reply_to ?? replyTo) : undefined,
              expiresInMs: typeof expires_in_ms === "number" ? expires_in_ms : undefined,
            });
          }
        } catch {
          // the sender's problem, not ours
        }
        done(204);
      });
      return;
    }

    if (req.method === "POST" && req.url === "/reply") {
      void readBody(req).then((body) => {
        try {
          const { id, text } = JSON.parse(body);
          if (typeof id === "string" && typeof text === "string") options.onReply?.(id, text);
        } catch {
          // the sender's problem, not ours
        }
        done(204);
      });
      return;
    }

    if (req.method === "POST" && req.url === "/context") {
      void readBody(req).then((body) => {
        try {
          const { currentSession } = JSON.parse(body);
          options.onContext?.({
            currentSession: typeof currentSession === "string" ? currentSession : undefined,
          });
        } catch {
          // the sender's problem, not ours
        }
        done(204);
      });
      return;
    }

    if (req.method === "GET" && req.url === "/state") {
      sessions.prune();
      return done(200, JSON.stringify(snapshot(sessions.list())));
    }

    if (req.method === "GET" && req.url === "/health") {
      return done(200, JSON.stringify({ uptimeMs: Date.now() - startedAt, eventsReceived }));
    }

    done(404);
  });

  // Running `npm start` while the launch agent is up is an easy mistake, and a raw
  // EADDRINUSE stack trace is a poor way to find that out. Registered here so it's in
  // place before anything else can attach to the server.
  server.on("error", (error: NodeJS.ErrnoException) => {
    if (error.code !== "EADDRINUSE") throw error;
    console.error(
      `✗ something is already listening on 127.0.0.1:${PORT}.\n` +
        "  That's probably the launch agent — either use it, or stop it first:\n" +
        "    launchctl bootout gui/$(id -u)/dev.gargoyle.hub",
    );
    process.exit(1);
  });

  return { server, sessions, health: () => ({ eventsReceived }) };
}
