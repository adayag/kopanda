import { describe, expect, it } from "vitest";
import net from "node:net";
import { lanAddresses } from "../../src/server/app.js";
import { loadConfig } from "../../src/server/config.js";
import { startLines, startServer } from "../../src/server/start.js";

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
  it("binds the configured host", async () => {
    const port = await freePort();
    const server = await startServer(loadConfig({ KOPANDA_STUDIO_PORT: String(port), KOPANDA_STUDIO_HOST: "127.0.0.1" }));
    try {
      expect(server.host).toBe("127.0.0.1");
      expect(server.port).toBe(port);
    } finally {
      await server.close();
    }
  });
});

describe("startLines", () => {
  it("names only the loopback address the server listens on", () => {
    expect(startLines("127.0.0.1", 4490)).toEqual(["listening on http://127.0.0.1:4490"]);
  });

  it("names each LAN address after the bound one on a LAN host", () => {
    expect(startLines("0.0.0.0", 4490)).toEqual([
      "listening on http://0.0.0.0:4490",
      ...lanAddresses("0.0.0.0").map((address) => `pull from the Kindle at http://${address}:4490`),
    ]);
  });
});
