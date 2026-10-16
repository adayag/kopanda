import type { Server } from "node:http";
import { createApp, lanAddresses, type AppOptions } from "./app.js";
import type { Config } from "./config.js";

export interface RunningServer {
  /** The address the server is bound to. */
  host: string;
  port: number;
  close(): Promise<void>;
}

export function startServer(config: Config, options: AppOptions = {}): Promise<RunningServer> {
  const app = createApp(config, options);
  return new Promise((resolve, reject) => {
    const server: Server = app.listen(config.port, config.host);
    const onError = (err: NodeJS.ErrnoException) => {
      server.off("listening", onListening);
      if (err.code === "EADDRINUSE") {
        reject(
          new Error(`Port ${config.port} is already in use; set KOPANDA_STUDIO_PORT to a free port`),
        );
      } else {
        reject(err);
      }
    };
    const onListening = () => {
      server.off("error", onError);
      const address = server.address();
      const bound = typeof address === "object" && address ? address : undefined;
      resolve({
        host: bound?.address ?? config.host,
        port: bound?.port ?? config.port,
        close: () =>
          new Promise<void>((done, fail) =>
            server.close((err) => (err ? fail(err) : done())),
          ),
      });
    };
    server.once("error", onError);
    server.once("listening", onListening);
  });
}

/** What the server prints once it listens: the bound address and, on a LAN host, each address the Kindle can use. */
export function startLines(host: string, port: number): string[] {
  return [
    `listening on http://${host}:${port}`,
    ...lanAddresses(host).map((address) => `pull from the Kindle at http://${address}:${port}`),
  ];
}
