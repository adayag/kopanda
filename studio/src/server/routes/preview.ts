import express from "express";
import { schema } from "../../schema.js";
import { HttpError } from "../http-error.js";
import { createPreviewQueue, PreviewError, renderPreview, type PreviewQueue } from "../preview.js";
import { resolveProfile } from "./settings.js";

export interface PreviewOptions {
  /** The script to run; the repo's bin/preview by default. */
  command?: string;
  /** How long a render may take; renderPreview's 150 s by default. */
  timeoutMs?: number;
  /** The queue renders wait in; one of the router's own by default. */
  queue?: PreviewQueue;
}

const lookKey = schema.keys.find((key) => key.id === "look");
const LOOKS = lookKey?.type === "choice" ? lookKey.choices.map((choice) => choice.value) : [];

/**
 * The preview over the profiles directory `dir`, mounted on the profiles router: the profile's home
 * rendered by bin/preview in one look, day or night, one render at a time. A request whose client
 * goes while it waits never runs; one already running finishes and its answer is dropped.
 */
export function previewRouter(dir: string, options: PreviewOptions = {}): express.Router {
  const router = express.Router();
  const queue = options.queue ?? createPreviewQueue();

  router.post("/:id/preview", express.json(), async (req, res) => {
    const body: unknown = req.body;
    const { look, night } = typeof body === "object" && body !== null ? (body as { look?: unknown; night?: unknown }) : {};
    if (typeof look !== "string" || !LOOKS.includes(look)) {
      throw new HttpError(400, `look must be one of ${LOOKS.join(", ")}`);
    }
    if (typeof night !== "boolean") throw new HttpError(400, "night must be true or false");
    const profile = await resolveProfile(dir, req.params.id);

    // The request's own close fires once its body is read; the response's fires when the client goes.
    const gone = new AbortController();
    res.on("close", () => {
      if (!res.writableFinished) gone.abort();
    });

    let png: Buffer;
    try {
      png = await queue.run(
        () =>
          renderPreview({
            command: options.command,
            timeoutMs: options.timeoutMs,
            width: profile.width,
            height: profile.height,
            dpi: profile.dpi,
            color: profile.color,
            look,
            night,
            settingsPath: profile.has_settings ? profile.settings_path : undefined,
          }),
        gone.signal,
      );
    } catch (err) {
      if (gone.signal.aborted) return;
      if (err instanceof PreviewError) {
        res.status(err.status).json({ error: err.error, log: err.log });
        return;
      }
      throw err;
    }
    if (gone.signal.aborted) return;
    res.set({ "Content-Type": "image/png", "Cache-Control": "no-store" }).send(png);
  });

  return router;
}
