import express from "express";
import { HttpError } from "../http-error.js";
import { getProfile, listProfiles } from "../profiles.js";
import { layoutFitRouter, type LayoutFitOptions } from "./layout-fit.js";
import { previewRouter, type PreviewOptions } from "./preview.js";
import { settingsRouter } from "./settings.js";

/** The profiles API over the profiles directory `dir`, read from disk on every request. */
export function profilesRouter(
  dir: string,
  layoutFit: LayoutFitOptions = {},
  preview: PreviewOptions = {},
): express.Router {
  const router = express.Router();

  router.get("/", async (_req, res) => {
    res.json(await listProfiles(dir));
  });

  router.get("/:id", async (req, res) => {
    const { id } = req.params;
    const profile = await getProfile(dir, id);
    if (profile === undefined) throw new HttpError(404, `no profile "${id}"`);
    if ("error" in profile) throw new HttpError(404, `profile "${id}" is invalid: ${profile.error}`);
    res.json(profile);
  });

  router.use(settingsRouter(dir));
  router.use(layoutFitRouter(dir, layoutFit));
  router.use(previewRouter(dir, preview));

  return router;
}
