import express from "express";
import type { Config } from "./config.js";
import { profilesRouter } from "./routes/profiles.js";

export interface AppOptions {
  /** Directory holding the built UI (index.html and assets). Omit in dev; Vite serves it. */
  uiDir?: string;
  /** Further API routes, mounted under /api ahead of its 404. */
  api?: express.Router;
}

export function createApp(config: Config, options: AppOptions = {}): express.Express {
  const app = express();

  app.use("/api/profiles", profilesRouter(config.profilesDir));

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
