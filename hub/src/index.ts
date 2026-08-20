import { createHub, PORT } from "./server.ts";
import { attachWebSocket } from "./transport/websocket.ts";
import type { Snapshot } from "./domain/state.ts";

// The socket is created first so the hub can publish into it, then attached to the
// same server — one port for both the event endpoint and the pets.
let publish: (s: Snapshot) => void = () => {};

const { server } = createHub(undefined, (snapshot) => publish(snapshot));
publish = attachWebSocket(server).publish;

server.listen(PORT, "127.0.0.1", () => {
  console.log(`gargoyle hub listening on 127.0.0.1:${PORT}`);
});
