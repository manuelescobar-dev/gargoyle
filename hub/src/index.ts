import { createHub, PORT } from "./server.ts";
import { attachWebSocket } from "./transport/websocket.ts";
import { situationFor } from "./domain/voice.ts";
import { menuFor } from "./domain/menu.ts";
import type { Snapshot } from "./domain/state.ts";

// The socket is created first so the hub can publish into it, then attached to the
// same server — one port for both the event endpoint and the pets.
let socket: ReturnType<typeof attachWebSocket> | null = null;
let previous: Snapshot | null = null;

const { server } = createHub(
  undefined,
  (snapshot) => {
    socket?.publish(snapshot);
    socket?.sendMenu(menuFor(snapshot));

  // Speaks rarely and only about things its body doesn't already show.
    const situation = situationFor(previous, snapshot);
    if (situation) socket?.speak(situation);
    previous = snapshot;
  },
  (id) => {
    // TODO(#13): focus the waiting agent's terminal. Logged for now so the popover is
    // wired end to end and the next piece is a handler, not a rewrite.
    console.log(`action: ${id}`);
  },
);

socket = attachWebSocket(server);

server.listen(PORT, "127.0.0.1", () => {
  console.log(`gargoyle hub listening on 127.0.0.1:${PORT}`);
});
