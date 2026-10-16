import type { Server } from "node:http";
import { createApp, type AppOptions } from "./app.js";
import type { Config } from "./config.js";

/** The server binds to loopback only. */
export const HOST = "127.0.0.1";

export interface RunningServer {
  port: number;
  close(): Promise<void>;
}

export function startServer(config: Config, options: AppOptions = {}): Promise<RunningServer> {
  const app = createApp(config, options);
  return new Promise((resolve, reject) => {
    const server: Server = app.listen(config.port, HOST);
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
