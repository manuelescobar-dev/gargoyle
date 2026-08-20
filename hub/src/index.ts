import { createHub, PORT } from "./server.ts";

const { server } = createHub();
server.listen(PORT, "127.0.0.1", () => {
  console.log(`gargoyle hub listening on 127.0.0.1:${PORT}`);
});
