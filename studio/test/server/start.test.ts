import { describe, expect, it } from "vitest";
import net from "node:net";
import { loadConfig } from "../../src/server/config.js";
import { startServer } from "../../src/server/start.js";

/** A port free on loopback a moment ago. */
function freePort(): Promise<number> {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address() as net.AddressInfo;
      server.close(() => resolve(port));
    });
  });
}

describe("startServer", () => {
  it("binds loopback even when an old environment still sets KOPANDA_STUDIO_HOST", async () => {
    const port = await freePort();
    const server = await startServer(loadConfig({ KOPANDA_STUDIO_PORT: String(port), KOPANDA_STUDIO_HOST: "0.0.0.0" }));
    try {
      expect(server.host).toBe("127.0.0.1");
      expect(server.port).toBe(port);
    } finally {
      await server.close();
    }
  });
});
