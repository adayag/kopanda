import express from "express";
import { HttpError } from "../http-error.js";
import { checkFit } from "../layout-fit.js";
import { readSettings } from "../settings-file.js";
import { resolveProfile } from "./settings.js";

export interface LayoutFitOptions {
  /** The script to run; the repo's bin/layout-fit by default. */
  command?: string;
  /** How long to wait for its answer; checkFit's 30 s by default. */
  timeoutMs?: number;
}

/**
 * The fit check over the profiles directory `dir`, mounted on the profiles router: how many rows
 * the home leaves out for the profile's current layout.rows (stored, else the default) and for the
 * proposed rows. Any failure to check answers 200, unchecked with its reason.
 */
export function layoutFitRouter(dir: string, options: LayoutFitOptions = {}): express.Router {
  const router = express.Router();

  router.post("/:id/layout-fit", express.json(), async (req, res) => {
    const profile = await resolveProfile(dir, req.params.id);
    const body: unknown = req.body;
    const proposed = typeof body === "object" && body !== null ? (body as { rows?: unknown }).rows : undefined;
    if (proposed === undefined) throw new HttpError(400, "the body has no rows");
    const { values } = await readSettings(profile.settings_path);
    res.json(
      await checkFit({
        command: options.command,
        timeoutMs: options.timeoutMs,
        width: profile.width,
        height: profile.height,
        dpi: profile.dpi,
        settingsPath: profile.settings_path,
        current: values["layout.rows"],
        proposed,
      }),
    );
  });

  return router;
}
