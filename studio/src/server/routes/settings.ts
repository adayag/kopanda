import express from "express";
import { HttpError } from "../http-error.js";
import { getProfile, type ProfileWithPath } from "../profiles.js";
import { readSettings, SettingsWriteError, writeSetting, type SettingsRead } from "../settings-file.js";

const STATUS = { unknown_key: 404, invalid_value: 400, not_writable: 409 } as const;

/** The listed, valid profile with this id; 404 otherwise. The id is never joined into a path. */
export async function resolveProfile(dir: string, id: string): Promise<ProfileWithPath> {
  const profile = await getProfile(dir, id);
  if (profile === undefined) throw new HttpError(404, `no profile "${id}"`);
  if ("error" in profile) throw new HttpError(404, `profile "${id}" is invalid: ${profile.error}`);
  return profile;
}

function answer(file: string, read: SettingsRead) {
  return {
    path: file,
    exists: read.exists,
    state: read.state,
    ...(read.reason === undefined ? {} : { reason: read.reason }),
    schema_version: read.schemaVersion,
    values: read.values,
    invalid: read.invalid,
    unknown: read.unknown,
  };
}

/** A profile's settings file over the profiles directory `dir`, mounted on the profiles router. */
export function settingsRouter(dir: string): express.Router {
  const router = express.Router();

  router.get("/:id/settings", async (req, res) => {
    const profile = await resolveProfile(dir, req.params.id);
    res.json(answer(profile.settings_path, await readSettings(profile.settings_path)));
  });

  router.put("/:id/settings/:key", express.json(), async (req, res) => {
    const profile = await resolveProfile(dir, req.params.id);
    const body: unknown = req.body;
    const value = typeof body === "object" && body !== null ? (body as { value?: unknown }).value : undefined;
    try {
      res.json(answer(profile.settings_path, await writeSetting(profile.settings_path, req.params.key, value)));
    } catch (err) {
      if (err instanceof SettingsWriteError) throw new HttpError(STATUS[err.reason], err.message, { cause: err });
      throw err;
    }
  });

  return router;
}
