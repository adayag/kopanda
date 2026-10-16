import express from "express";
import os from "node:os";
import type { Config } from "./config.js";
import { isLoopback, lanGuard } from "./lan-guard.js";
import { geocodeRouter, type GeocodeOptions } from "./routes/geocode.js";
import type { LayoutFitOptions } from "./routes/layout-fit.js";
import { profilesRouter } from "./routes/profiles.js";
import { pushRouter } from "./routes/push.js";

export interface AppOptions {
  /** Directory holding the built UI (index.html and assets). Omit in dev; Vite serves it. */
  uiDir?: string;
  /** Further API routes, mounted under /api ahead of its 404. */
  api?: express.Router;
  /** The fit check's command and timeout; the repo's bin/layout-fit and 30 s by default. */
  layoutFit?: LayoutFitOptions;
  /** How the place search reaches Open-Meteo; the global fetch and 10 s by default. */
  geocode?: GeocodeOptions;
  /** The plugin folder the push routes bundle; the repo's kopanda.koplugin/ by default. */
  pluginDir?: string;
}

/**
 * What GET /api/health answers: the address and port the server is bound to and, when that is not loopback, this
 * machine's LAN IPv4 addresses, for the Kindle to be pointed at.
 */
export interface Health {
  ok: true;
  host: string;
  port: number;
  addresses: string[];
}

/** This machine's non-internal IPv4 addresses when `host` is not loopback; none when it is. */
export function lanAddresses(host: string): string[] {
  if (host === "localhost" || isLoopback(host)) return [];
  return Object.values(os.networkInterfaces())
    .flatMap((infos) => infos ?? [])
    .filter((info) => info.family === "IPv4" && !info.internal)
    .map((info) => info.address);
}

export function createApp(config: Config, options: AppOptions = {}): express.Express {
  const app = express();

  // First, so another machine reaches nothing else: not the other routes and not the UI's files.
  app.use(lanGuard);

  app.get("/api/health", (_req, res) => {
    res.json({ ok: true, host: config.host, port: config.port, addresses: lanAddresses(config.host) } satisfies Health);
  });

  app.use("/api/profiles", profilesRouter(config.profilesDir, options.layoutFit));
  app.use("/api/push", pushRouter(config.profilesDir, options.pluginDir));
  app.use("/api/geocode", geocodeRouter(options.geocode));

  if (options.api) {
    app.use("/api", options.api);
  }

  app.use("/api", (req, res) => {
    res.status(404).json({ error: `not found: ${req.method} ${req.baseUrl}${req.path}` });
  });

  if (options.uiDir) {
    app.use(express.static(options.uiDir));
  }

  app.use(
    (err: unknown, _req: express.Request, res: express.Response, next: express.NextFunction) => {
      if (res.headersSent) {
        next(err);
        return;
      }
      const status = errorStatus(err);
      if (status >= 500) console.error(err);
      res.status(status).json({ error: err instanceof Error ? err.message : String(err) });
    },
  );

  return app;
}

function errorStatus(err: unknown): number {
  if (typeof err === "object" && err !== null) {
    const { status, statusCode } = err as { status?: unknown; statusCode?: unknown };
    for (const candidate of [status, statusCode]) {
      if (typeof candidate === "number" && candidate >= 400 && candidate < 600) return candidate;
    }
  }
  return 500;
}
