import { createHub, PORT } from "./server.ts";
import { attachWebSocket } from "./transport/websocket.ts";
import { situationFor } from "./domain/voice.ts";
import { menuFor } from "./domain/menu.ts";
import { Sessions } from "./domain/sessions.ts";
import type { Snapshot } from "./domain/state.ts";

// The socket is created first so the hub can publish into it, then attached to the
// same server — one port for both the event endpoint and the pets.
let socket: ReturnType<typeof attachWebSocket> | null = null;
let previous: Snapshot | null = null;

const sessions = new Sessions();

const { server } = createHub(
  sessions,
  (snapshot) => {
    socket?.publish(snapshot);
    socket?.sendMenu(menuFor(snapshot));

  // Speaks rarely and only about things its body doesn't already show.
    const situation = situationFor(previous, snapshot);
    if (situation) socket?.speak(situation);
    previous = snapshot;
  },
  (id) => {
    if (!id.startsWith("focus:")) return;

    const session = sessions.find(id.slice("focus:".length));
    if (!session?.terminal) {
      console.log(`focus: no terminal recorded for ${id}`);
      return;
    }

    // The hub works out *which* terminal; the pet raises it. macOS won't grant Automation
    // rights to a launchd agent — there's no GUI identity to attribute a prompt to, so it
    // fails silently. The pet is a real app and can be asked properly.
    socket?.focus(session.terminal);
  },
);

socket = attachWebSocket(server);

server.listen(PORT, "127.0.0.1", () => {
  console.log(`gargoyle hub listening on 127.0.0.1:${PORT}`);
});
