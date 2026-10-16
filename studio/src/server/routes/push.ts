import express from "express";
import { buildBundle, type Bundle } from "../bundle.js";
import { HttpError } from "../http-error.js";
import { getProfile, listProfiles } from "../profiles.js";

/**
 * The routes the device pulls a profile's bundle through, over the profiles directory `dir` and the
 * plugin folder `pluginDir` (the repo's kopanda.koplugin/ by default). Each request reads the
 * profiles and builds the bundle from disk again; nothing is cached.
 */
export function pushRouter(dir: string, pluginDir?: string): express.Router {
  const router = express.Router();

  /** The valid listed profile with this id's bundle; 404 for any other id. */
  async function bundleOf(id: string): Promise<Bundle> {
    const profile = await getProfile(dir, id);
    if (profile === undefined) throw new HttpError(404, `no profile "${id}"`);
    if ("error" in profile) throw new HttpError(404, `profile "${id}" is invalid: ${profile.error}`);
    return buildBundle({ pluginDir, settingsPath: profile.settings_path });
  }

  router.get("/profiles", async (_req, res) => {
    const { profiles } = await listProfiles(dir);
    res.json({
      profiles: profiles.flatMap((profile) =>
        "error" in profile ? [] : [{ id: profile.id, name: profile.name, device: profile.device }],
      ),
    });
  });

  router.get("/:id/manifest", async (req, res) => {
    const { id } = req.params;
    res.json((await bundleOf(id)).manifestFor(id));
  });

  router.get("/:id/files/:hash/*path", async (req, res) => {
    const { id, hash } = req.params;
    const bundle = await bundleOf(id);
    if (hash !== bundle.hash) {
      res.status(409).json({
        error: `profile "${id}" changed in the studio since that manifest; pull again`,
        hash: bundle.hash,
      });
      return;
    }
    // The wildcard arrives as its decoded segments; the path is only ever a key of the bundle.
    const rel = req.params.path.join("/");
    const bytes = bundle.files.get(rel);
    if (bytes === undefined) throw new HttpError(404, `no file "${rel}" in profile "${id}"'s bundle`);
    res.set({ "Content-Type": "application/octet-stream", "Cache-Control": "no-store" });
    res.send(Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength));
  });

  return router;
}
